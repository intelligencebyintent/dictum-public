import Foundation

/// Builds the currently-selected transcription engine and LLM provider from
/// `AppSettings`. Centralizes wiring so the dictation pipeline doesn't know
/// about concrete engine types.
@MainActor
public final class EngineRegistry {
    private let settings: AppSettings

    /// One prepared transcription engine shared by Settings ("Download & load")
    /// and the dictation pipeline, so warming the model once benefits both.
    private var prepared: (key: String, engine: any TranscriptionEngine)?
    /// In-flight prepare, so concurrent callers await the same work. Tracked with
    /// a `token` so bookkeeping keys on task IDENTITY, not the (recurring) key.
    private var preparing: (key: String, token: Int, task: Task<any TranscriptionEngine, Error>)?
    /// Bumped whenever the desired engine/model changes (`resetPreparedEngine`). A
    /// prepare begun under a stale epoch must not populate the cache.
    private var epoch = 0
    /// Monotonic id handed to each in-flight prepare.
    private var nextToken = 0

    public init(settings: AppSettings) {
        self.settings = settings
    }

    public func currentTranscriptionModel() -> TranscriptionModel {
        settings.selectedTranscriptionModel(for: settings.transcriptionEngineID)
    }

    /// Identity of the currently-selected engine+model.
    private func currentKey() -> String {
        "\(settings.transcriptionEngineID.rawValue)-\(currentTranscriptionModel().id)"
    }

    /// Whether the currently-selected engine+model is already prepared in memory.
    public var isCurrentEnginePrepared: Bool {
        prepared?.key == currentKey()
    }

    /// Return a prepared engine for the current settings, reusing the cached one
    /// when the engine+model is unchanged. Engines download (first run only) and
    /// load CoreML. Concurrent calls for the same key share one prepare task.
    public func preparedTranscriptionEngine(
        progress: @Sendable @escaping (Double) -> Void = { _ in }
    ) async throws -> any TranscriptionEngine {
        let key = currentKey()

        if let prepared, prepared.key == key { progress(1); return prepared.engine }
        if let preparing, preparing.key == key { return try await preparing.task.value }

        // Switching engine/model — drop the old one. Unload OFF this task (no
        // await here) so `preparing` is established synchronously: on the main
        // actor the whole prologue is then atomic and a concurrent caller can't
        // slip through a dedup gap while we await an unload.
        if let old = prepared {
            prepared = nil
            Task { await old.engine.unload() }
        }

        let startEpoch = epoch
        nextToken += 1
        let token = nextToken
        let engine = try makeTranscriptionEngine()
        let model = currentTranscriptionModel()
        let task = Task<any TranscriptionEngine, Error> {
            try await engine.prepare(model: model, progress: progress)
            return engine
        }
        preparing = (key, token, task)
        defer { if preparing?.token == token { preparing = nil } }

        let ready = try await task.value
        // Only cache if nothing invalidated this prepare meanwhile. The prepare
        // body isn't cancellation-aware, so a `resetPreparedEngine` can't stop the
        // download/load — but it bumps `epoch`, and we then refuse to cache the
        // now-stale result under the old key (the caller still gets it for this
        // one use; ARC reclaims it afterwards).
        if epoch == startEpoch, currentKey() == key {
            prepared = (key, ready)
        }
        return ready
    }

    /// Drop any prepared/in-flight engine (e.g. when the user changes engine/model).
    public func resetPreparedEngine() {
        epoch += 1
        let old = prepared
        prepared = nil
        preparing?.task.cancel()
        preparing = nil
        if let old { Task { await old.engine.unload() } }
    }

    /// Construct the transcription engine for the current settings.
    public func makeTranscriptionEngine() throws -> any TranscriptionEngine {
        let id = settings.transcriptionEngineID
        let model = settings.selectedTranscriptionModel(for: id)

        switch id {
        case .parakeet:
            return ParakeetEngine(model: model)
        }
    }

    /// Construct the LLM provider used for Polish / Command Mode: Apple's
    /// on-device model, or a local server (the client refuses any non-loopback
    /// base URL).
    public func makeLLMProvider() -> any LLMProvider {
        let id = settings.llmProviderID
        if id == .appleOnDevice, #available(macOS 26.0, *) { return AppleOnDeviceProvider() }
        return OpenAICompatibleProvider(id: id, baseURL: settings.baseURL(for: id))
    }

    /// Whether AI Polish / rewrites can run: Apple's model must be available
    /// (Apple Intelligence on, model downloaded), or the configured server URL
    /// must be a loopback address. (A model must also be selected; see
    /// `currentLLMModel`.)
    public var canPolish: Bool {
        let id = settings.llmProviderID
        guard id.usesServer else {
            if #available(macOS 26.0, *) { return AppleOnDeviceProvider.isAvailable }
            return false
        }
        return LocalEndpoint.isLoopback(settings.baseURL(for: id))
    }

    public func currentLLMModel() -> LLMModel? {
        let id = settings.llmProviderID
        guard let modelID = settings.selectedLLMModelID(for: id) else { return nil }
        let known = ModelCatalog.chatModels(for: id).first { $0.id == modelID }
        return known ?? LLMModel(id: modelID)
    }
}
