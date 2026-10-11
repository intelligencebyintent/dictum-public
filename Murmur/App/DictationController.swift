import AppKit
import ApplicationServices
import AVFoundation
import MurmurKit
import Observation
import SwiftData

/// The dictation pipeline state machine — the brain that orchestrates audio
/// capture, transcription, AI Polish, and text insertion.
///
/// `idle → (listening →) recording → transcribing → polishing → inserting → idle`
/// (cancel or error → idle). The HUD and status item observe `state`/`levels`.
@MainActor
@Observable
final class DictationController {
    enum State: Equatable {
        case idle
        /// A hold key is down and audio is being captured, but the press hasn't
        /// passed 250 ms yet, so it may still be a tap or a shortcut. No HUD.
        case listening
        case recording
        case transcribing
        case polishing
        case inserting
        case downloading(Double)   // local model first-run
        case error(String)

        /// Whether the HUD shows.
        var isVisible: Bool { self != .idle && self != .listening }
    }

    private(set) var state: State = .idle
    /// Recent RMS levels (newest last) for the live waveform.
    private(set) var levels: [Float] = []
    /// Recording until the next tap or 3 s of silence, rather than while a key
    /// is held.
    private(set) var isHandsFree = false

    private let settings: AppSettings
    private let registry: EngineRegistry
    private let audio: AudioCaptureEngine
    private let insertion: TextInsertionService
    private let accessibility: AccessibilityReader
    private let polish = PolishService()
    private let rewrite = RewriteService()

    private enum Mode { case dictation, command }
    private var mode: Mode = .dictation
    /// Held with the high-accuracy key (Right ⌥).
    private var highAccuracy = false

    // Hands-free silence auto-stop
    private var silenceStart: Date?
    private var hasSpoken = false
    /// Silence cutoff on the *compressed* level scale (`min(1, sqrt(rms)*2.5)`
    /// from AudioCaptureEngine). Typical room ambient compresses to ~0.05–0.11
    /// and speech to ~0.3–1.0; 0.15 sits cleanly between so hands-free actually
    /// auto-stops on real silence (0.06 was below the ambient floor and never fired).
    private let silenceThreshold: Float = 0.15
    /// Hands-free recording stops after 3 seconds of silence.
    private let silenceTimeout: TimeInterval = 3.0

    /// SwiftData context for History (set by `AppDelegate`).
    var historyContext: ModelContext?

    private var targetApp: AccessibilityReader.FrontmostApp?
    private var commandSelection: String?
    private var recordingStart: Date?
    private var errorResetTask: Task<Void, Never>?
    private var pipelineTask: Task<Void, Never>?
    /// Bumped whenever a dictation starts or is cancelled. A pipeline that finds
    /// it changed was cancelled (Esc) or superseded, and must not insert or
    /// touch the HUD.
    private var session = 0
    /// The last text Dictum produced, for Paste Last. Memory only.
    private var lastResult: String?

    private let maxLevels = 48
    /// Presses under 250 ms are ignored.
    private let minRecordingDuration: TimeInterval = 0.25

    init(
        settings: AppSettings,
        registry: EngineRegistry,
        audio: AudioCaptureEngine = AudioCaptureEngine(),
        insertion: TextInsertionService,
        accessibility: AccessibilityReader
    ) {
        self.settings = settings
        self.registry = registry
        self.audio = audio
        self.insertion = insertion
        self.accessibility = accessibility
    }

    // MARK: Intents

    /// Audio is being captured (provisionally or confirmed).
    var isRecording: Bool { state == .listening || state == .recording }

    /// Whether Esc has something to cancel.
    var isCancellable: Bool {
        switch state {
        case .recording, .transcribing, .polishing, .downloading: true
        default: false
        }
    }

    /// Whether a new dictation can start. An error notice or the tail of an
    /// insert (clipboard restore) doesn't block the next one.
    private var canStart: Bool {
        switch state {
        case .idle, .error, .inserting: true
        default: false
        }
    }

    /// ⌃⌥D, the menu, and Shortcuts: start hands-free (stops on the next
    /// toggle or after 3 s of silence), or stop if recording.
    func toggle() {
        if isRecording {
            finish()
        } else {
            startRecording(mode: .dictation, provisional: false, handsFree: true)
        }
    }

    /// Command Mode toggle: speak an instruction to edit the current selection.
    func toggleCommand() {
        if state == .recording, mode == .command {
            finish()
        } else if !isRecording {
            startRecording(mode: .command, provisional: false, handsFree: false)
        }
    }

    /// Hold key down: capture now so the first word isn't clipped, but keep the
    /// HUD hidden until `confirmHold()` (the press may be a tap or a shortcut).
    func beginHold(highAccuracy: Bool) {
        startRecording(mode: .dictation, provisional: true, handsFree: false, highAccuracy: highAccuracy)
    }

    /// The hold passed 250 ms: it's a real dictation, so show the HUD.
    func confirmHold() {
        guard state == .listening else { return }
        state = .recording
    }

    /// A tap or a shortcut: drop the audio and show nothing.
    func discardHold() {
        guard isRecording else { return }
        session += 1
        audio.cancel()
        levels = []
        isHandsFree = false
        state = .idle
        Log.pipeline.info("Discarded a short tap or shortcut press")
    }

    /// The second tap of a double-tap: keep recording until the next tap or
    /// 3 s of silence.
    func continueHandsFree() {
        guard isRecording else { return }
        isHandsFree = true
        silenceStart = nil
        hasSpoken = false
        state = .recording
    }

    private func startRecording(mode: Mode, provisional: Bool, handsFree: Bool, highAccuracy: Bool = false) {
        guard canStart else { return }

        // Surface a denied mic instead of silently recording silence. `.notDetermined`
        // still proceeds — AVAudioEngine.start() triggers the first-run system prompt.
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        if micStatus == .denied || micStatus == .restricted {
            fail(TranscriptionError.unsupported("Microphone access is off for Dictum. Turn it on in System Settings → Privacy & Security → Microphone."))
            return
        }

        session += 1
        self.mode = mode
        self.highAccuracy = highAccuracy
        isHandsFree = handsFree
        silenceStart = nil
        hasSpoken = false
        errorResetTask?.cancel()
        targetApp = accessibility.frontmostApp()
        // Capture the selection now (before our HUD/paste changes focus) for Command Mode.
        commandSelection = mode == .command ? accessibility.selectedText() : nil
        levels = []
        recordingStart = Date()

        do {
            try audio.start(deviceUID: settings.inputDeviceUID) { [weak self] level in
                Task { @MainActor in self?.appendLevel(level) }
            }
            state = provisional ? .listening : .recording
            Log.pipeline.info("Recording started (mode=\(String(describing: mode), privacy: .public), highAccuracy=\(highAccuracy), handsFree=\(handsFree))")
        } catch {
            Log.pipeline.error("audio.start failed: \(error, privacy: .public)")
            fail(error)
        }
    }

    func finish() {
        guard isRecording else { return }
        let samples = audio.stop()
        let duration = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        isHandsFree = false
        Log.pipeline.info("finish: \(samples.count) samples, \(String(format: "%.2f", duration))s")

        guard duration >= minRecordingDuration, !samples.isEmpty else {
            Log.pipeline.info("Discarded: too short or empty (need ≥\(self.minRecordingDuration)s and audio). Check Microphone permission.")
            state = .idle
            return
        }
        state = .transcribing
        let id = session
        let currentMode = mode
        let highAccuracy = self.highAccuracy
        pipelineTask = Task {
            if currentMode == .command {
                await runCommandPipeline(samples: samples, session: id)
            } else {
                await runPipeline(samples: samples, duration: duration, highAccuracy: highAccuracy, session: id)
            }
        }
    }

    /// Run a Transform: apply a saved rewrite instruction to the current selection.
    func runTransform(_ index: Int) {
        guard canStart, !isRecording else { return }
        let transforms = settings.transforms
        guard index < transforms.count else { return }
        let instruction = transforms[index].prompt
        session += 1
        let id = session
        pipelineTask = Task { await applyRewrite(instruction: instruction, spokenSelection: nil, session: id) }
    }

    /// Esc: drop the audio, or the result still being worked on. Inserts nothing.
    func cancel() {
        guard state != .idle else { return }
        session += 1
        pipelineTask?.cancel()
        audio.cancel()
        errorResetTask?.cancel()
        levels = []
        isHandsFree = false
        state = .idle
        Log.pipeline.info("Cancelled; nothing inserted")
    }

    /// Paste Last (⌃⌥V): insert the last result again.
    func pasteLast() {
        guard canStart, !isRecording else { return }
        guard let text = lastResult ?? latestHistoryText() else {
            show("Nothing to paste yet.")
            return
        }
        session += 1
        let id = session
        pipelineTask = Task { await deliver(text, session: id, noun: "text") }
    }

    // MARK: Pipeline

    private func runPipeline(samples: [Float], duration: TimeInterval, highAccuracy: Bool, session id: Int) async {
        do {
            guard let (raw, text) = try await process(samples: samples, highAccuracy: highAccuracy, session: id) else {
                update(.idle, for: id)
                return
            }
            guard id == session else { return }   // cancelled with Esc

            // Always save the transcript first, so it's never lost if paste can't run.
            recordHistory(raw: raw, final: text, duration: duration)
            lastResult = text
            await deliver(text, session: id, noun: "text")
        } catch {
            guard id == session else { return }
            fail(error)
        }
    }

    /// Insert at the cursor, and say so when the text couldn't go in normally.
    private func deliver(_ text: String, session id: Int, noun: String) async {
        guard insertion.isTrusted else {
            handleUntrusted(text, noun: noun)
            return
        }
        // Check before showing "Inserted".
        if insertion.focusedFieldIsSecure() {
            Log.insertion.info("Refused: the focused field is a password field")
            show("That's a password field, so Dictum didn't type there.")
            return
        }
        state = .inserting
        let outcome = await insertion.insert(text)
        Log.insertion.info("Inserted \(text.count, privacy: .public) chars: \(String(describing: outcome), privacy: .public)")
        guard id == session else { return }   // a newer dictation owns the HUD
        switch outcome {
        case .pasted, .accessibility:
            state = .idle
        case .copiedToClipboard:
            show("Couldn't type here. Your \(noun) is on the clipboard: press ⌘V.")
        case .refusedSecureField:
            show("That's a password field, so Dictum didn't type there.")
        }
    }

    private struct Vocabulary {
        var terms: [String]                          // spelling/biasing hints
        var replacements: [(from: String, to: String)]
        var snippets: [(from: String, to: String)]
    }

    private func loadVocabulary() -> Vocabulary {
        guard let context = historyContext else { return Vocabulary(terms: [], replacements: [], snippets: []) }
        let entries = (try? context.fetch(FetchDescriptor<DictionaryEntry>())) ?? []
        let snippets = (try? context.fetch(FetchDescriptor<Snippet>())) ?? []
        return Vocabulary(
            terms: entries.map(\.phrase),
            replacements: entries.compactMap { entry in
                guard let replacement = entry.replacement, !replacement.isEmpty else { return nil }
                return (from: entry.phrase, to: replacement)
            },
            snippets: snippets.map { (from: $0.trigger, to: $0.expansion) }
        )
    }

    /// Transcribe, clean up, and apply dictionary replacements: everything a
    /// dictation does except capture and paste. Returns nil for an empty
    /// transcript. Shared by dictation and the DEBUG Network Guard self-test.
    /// `session` is nil for the self-test, which doesn't share the HUD.
    func process(samples: [Float], highAccuracy: Bool = false, session id: Int? = nil) async throws -> (raw: String, final: String)? {
        let vocab = loadVocabulary()

        if highAccuracy {
            // A dedicated high-accuracy engine isn't built in yet; until then it's Parakeet.
            Log.pipeline.info("High-accuracy engine not installed yet; using the default engine")
        }
        let engine = try await prepareEngine(session: id)
        let options = TranscriptionOptions(
            language: settings.language,
            prompt: vocab.terms.isEmpty ? nil : vocab.terms.joined(separator: ", ")
        )
        let result = try await engine.transcribe(samples: samples, options: options)

        let raw = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        Log.pipeline.info("Transcribed \(raw.count) chars; trusted(paste)=\(self.insertion.isTrusted)")
        guard !raw.isEmpty else { Log.pipeline.info("Empty transcript — nothing to insert"); return nil }

        var text = raw
        if settings.polishEnabled {
            update(.polishing, for: id)
            text = await polished(raw, terms: vocab.terms)
        }

        // Literal dictionary replacements + snippet expansions.
        text = TextProcessing.applyReplacements(text, vocab.replacements + vocab.snippets)
        return (raw, text)
    }

    /// Command Mode: transcribe the spoken instruction, then apply it to the
    /// selection captured when recording started.
    private func runCommandPipeline(samples: [Float], session id: Int) async {
        do {
            let engine = try await prepareEngine(session: id)
            let result = try await engine.transcribe(samples: samples, options: TranscriptionOptions(language: settings.language))
            let instruction = result.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard id == session else { return }
            guard !instruction.isEmpty else { state = .idle; return }
            await applyRewrite(instruction: instruction, spokenSelection: commandSelection, session: id)
        } catch {
            guard id == session else { return }
            fail(error)
        }
    }

    /// Shared rewrite path for Transforms and Command Mode. Reads the selection
    /// (preferring an already-captured one), rewrites it, and pastes the result.
    private func applyRewrite(instruction: String, spokenSelection: String?, session id: Int) async {
        guard registry.canPolish, let model = registry.currentLLMModel() else {
            show("Needs LM Studio or Ollama and a model in Settings → AI Polish.")
            return
        }
        state = .polishing
        var selection = spokenSelection ?? accessibility.selectedText()
        if selection == nil {
            selection = await insertion.readSelectionViaCopy()
        }
        let provider = registry.makeLLMProvider()
        do {
            let output = try await rewrite.rewrite(instruction: instruction, selection: selection, provider: provider, model: model)
            guard id == session else { return }
            guard !output.isEmpty else { state = .idle; return }
            lastResult = output
            await deliver(output, session: id, noun: "result")
        } catch {
            guard id == session else { return }
            fail(error)
        }
    }

    private func recordHistory(raw: String, final: String, duration: TimeInterval) {
        guard let context = historyContext else { return }
        let item = HistoryItem(
            rawText: raw,
            polishedText: final,
            engineID: settings.transcriptionEngineID.rawValue,
            appName: targetApp?.name,
            durationMs: Int(duration * 1000)
        )
        context.insert(item)
        do {
            try context.save()
        } catch {
            // The transcript is still on the clipboard after paste, so it isn't
            // truly lost, but a persistent save failure shouldn't be silent.
            Log.pipeline.error("Failed to save history item: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Get the prepared engine from the shared registry cache, surfacing local
    /// download progress in the HUD. Settings "Download & load" warms the very
    /// same engine, so a model downloaded there is reused here instantly.
    private func prepareEngine(session id: Int?) async throws -> any TranscriptionEngine {
        let isLocal = settings.transcriptionEngineID.isLocal
        if isLocal, !registry.isCurrentEnginePrepared {
            update(.downloading(0), for: id)
        }
        let engine = try await registry.preparedTranscriptionEngine { [weak self] progress in
            Task { @MainActor in
                guard let self, isLocal, progress < 1 else { return }
                switch self.state {
                case .transcribing, .downloading: self.update(.downloading(progress), for: id)
                default: break
                }
            }
        }
        // A first-run download leaves the state at the last `downloading` value;
        // move back to `transcribing` so the HUD reflects the actual next step.
        if case .downloading = state { update(.transcribing, for: id) }
        return engine
    }

    /// Set the HUD state for pipeline `id`, unless it was cancelled or superseded.
    /// A nil `id` (the self-test) always updates.
    private func update(_ newState: State, for id: Int?) {
        guard id == nil || id == session else { return }
        state = newState
    }

    /// The most recent History entry, for Paste Last after a relaunch.
    private func latestHistoryText() -> String? {
        guard let context = historyContext else { return nil }
        var descriptor = FetchDescriptor<HistoryItem>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first?.insertedText
    }

    /// Run AI cleanup; on failure, fall back to the raw transcript.
    private func polished(_ raw: String, terms: [String]) async -> String {
        // No usable LLM (no key, no local server) → skip the call entirely and
        // insert the raw transcript instead of paying for a guaranteed-failing request.
        guard registry.canPolish, let model = registry.currentLLMModel() else { return raw }
        let provider = registry.makeLLMProvider()
        let context = PolishContext(
            frontmostAppName: targetApp?.name,
            frontmostBundleID: targetApp?.bundleID,
            dictionaryTerms: terms
        )
        do {
            return try await polish.polish(raw: raw, context: context, provider: provider, model: model)
        } catch {
            Log.pipeline.error("Polish failed, inserting raw transcript: \(error.localizedDescription)")
            return raw
        }
    }

    // MARK: Helpers

    private func appendLevel(_ level: Float) {
        levels.append(level)
        if levels.count > maxLevels { levels.removeFirst(levels.count - maxLevels) }

        guard isHandsFree, state == .recording else { return }
        if level > silenceThreshold {
            hasSpoken = true
            silenceStart = nil
        } else if hasSpoken {
            if let start = silenceStart {
                if Date().timeIntervalSince(start) > silenceTimeout { finish() }
            } else {
                silenceStart = Date()
            }
        }
    }

    /// Transcription succeeded but we can't paste (no Accessibility). Keep the
    /// text on the clipboard so it's never lost, surface a clear message, and
    /// guide the user to grant the permission (once per launch).
    private func handleUntrusted(_ text: String, noun: String) {
        Log.insertion.error("Not trusted for Accessibility — copied to clipboard instead of pasting")
        insertion.copyToClipboard(text)
        show("Turn on Accessibility for Dictum to paste. Your \(noun) is on the clipboard: press ⌘V.")
        promptForAccessibility()
    }

    private var didPromptForAccessibility = false
    /// Show the system Accessibility prompt (with an "Open System Settings"
    /// button) once, so the user can grant the permission that makes pasting work.
    private func promptForAccessibility() {
        guard !didPromptForAccessibility else { return }
        didPromptForAccessibility = true
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func fail(_ error: Error) {
        audio.cancel()
        isHandsFree = false
        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        Log.pipeline.error("Dictation failed: \(message, privacy: .public)")
        show(message)
    }

    /// Show a notice in the HUD for a few seconds.
    private func show(_ message: String) {
        state = .error(message)
        scheduleErrorReset()
    }

    #if DEBUG
    /// Drives the HUD into a fake recording state (no audio) for screenshots /
    /// design iteration. Triggered by the `-hudDemo` launch argument.
    func startDemo() {
        guard state == .idle else { return }
        state = .recording
        Task { @MainActor in
            for i in 0..<120 {
                try? await Task.sleep(for: .milliseconds(80))
                appendLevel(Float(abs(sin(Double(i) * 0.5)) * 0.9 + 0.1))
            }
            state = .idle
        }
    }
    #endif

    private func scheduleErrorReset() {
        errorResetTask?.cancel()
        errorResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            // If this task was superseded (another error scheduled a new reset),
            // don't fire — otherwise the cancelled task clears the NEW error early.
            guard !Task.isCancelled else { return }
            if case .error = self?.state { self?.state = .idle }
        }
    }
}
