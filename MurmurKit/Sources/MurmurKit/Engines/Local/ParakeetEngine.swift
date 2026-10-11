import FluidAudio
import Foundation

/// Local transcription via FluidAudio's Parakeet TDT (CoreML / Apple Neural
/// Engine). Models auto-download from Hugging Face on first `prepare`.
///
/// An actor: it owns the `AsrManager` and a reusable decoder state. Sync
/// protocol metadata (`id`, etc.) is satisfied by `nonisolated` members and the
/// protocol's default implementations.
public actor ParakeetEngine: TranscriptionEngine {
    public nonisolated let id = TranscriptionEngineID.parakeet

    private let version: AsrModelVersion
    private var manager: AsrManager?

    public init(model: TranscriptionModel) {
        switch model.id {
        case "parakeet-tdt-0.6b-v2": self.version = .v2
        default: self.version = .v3
        }
    }

    public func prepare(model: TranscriptionModel, progress: @Sendable @escaping (Double) -> Void) async throws {
        if manager != nil { progress(1); return }

        // Download into Murmur's own Application Support models directory (not
        // FluidAudio's library default) so all on-device models live in one place
        // that uninstall/cleanup can reason about. See `ModelStorage`.
        let models = try await AsrModels.downloadAndLoad(
            to: ModelStorage.parakeetDirectory,
            version: version,
            progressHandler: { p in progress(min(1, max(0, p.fractionCompleted))) }
        )
        let manager = AsrManager()
        try await manager.loadModels(models)

        self.manager = manager
        progress(1)
        Log.engine.info("Parakeet \(String(describing: self.version), privacy: .public) ready")
    }

    public func transcribe(samples: [Float], options: TranscriptionOptions) async throws -> TranscriptionResult {
        guard !samples.isEmpty else { throw TranscriptionError.emptyAudio }
        guard let manager else { throw TranscriptionError.modelNotPrepared }

        // A FRESH decoder state per dictation. The TDT decoder state is meant for
        // a continuous stream; reusing it across separate one-shot utterances
        // bleeds prior context in and produces garbled/empty output on the 2nd+
        // dictation.
        var state = try TdtDecoderState()
        let language = options.language.flatMap { Language(rawValue: $0) }
        let result = try await manager.transcribe(samples, decoderState: &state, language: language)

        return TranscriptionResult(
            text: result.text.trimmingCharacters(in: .whitespacesAndNewlines),
            language: options.language,
            confidence: Double(result.confidence),
            duration: result.duration
        )
    }

    public func unload() async {
        if let manager { await manager.cleanup() }
        manager = nil
    }
}
