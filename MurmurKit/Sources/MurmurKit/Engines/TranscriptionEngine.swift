import Foundation

// MARK: - Identity

/// Every transcription backend Dictum can use. All run on-device; there are no
/// cloud engines in this build (`PrivacyTests` enforces it).
public enum TranscriptionEngineID: String, Codable, CaseIterable, Sendable, Identifiable {
    case parakeet      // FluidAudio (NVIDIA Parakeet, CoreML/ANE)

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .parakeet: "Parakeet (local)"
        }
    }

    /// Every engine runs on-device. Kept so callers can show "local" in the UI.
    public var isLocal: Bool { true }
}

// MARK: - Model + options

/// A selectable model within an engine (e.g. a Parakeet version).
public struct TranscriptionModel: Identifiable, Codable, Sendable, Hashable {
    public let id: String              // engine-specific identifier
    public let displayName: String
    public let approxSizeMB: Int?
    public let isMultilingual: Bool

    public init(id: String, displayName: String, approxSizeMB: Int? = nil, isMultilingual: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.approxSizeMB = approxSizeMB
        self.isMultilingual = isMultilingual
    }
}

public struct TranscriptionOptions: Sendable {
    /// BCP-47 / ISO language code, or `nil` to auto-detect.
    public var language: String?
    /// Optional priming text to bias vocabulary (names, jargon).
    public var prompt: String?

    public init(language: String? = nil, prompt: String? = nil) {
        self.language = language
        self.prompt = prompt
    }
}

public struct TranscriptionResult: Sendable {
    public var text: String
    public var language: String?
    public var confidence: Double?
    public var duration: TimeInterval?

    public init(text: String, language: String? = nil, confidence: Double? = nil, duration: TimeInterval? = nil) {
        self.text = text
        self.language = language
        self.confidence = confidence
        self.duration = duration
    }
}

// MARK: - Errors

/// Helpers for turning a raw HTTP error body into something fit for a user-facing
/// HUD message — local LLM servers can return multi-kilobyte error pages.
enum HTTPBody {
    static func summarize(_ body: String, limit: Int = 200) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        // Collapse whitespace/newlines so a wrapped HTML page reads as one line.
        let collapsed = trimmed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return collapsed.count > limit ? String(collapsed.prefix(limit)) + "…" : collapsed
    }
}

public enum TranscriptionError: LocalizedError {
    case modelNotPrepared
    case emptyAudio
    case unsupported(String)

    public var errorDescription: String? {
        switch self {
        case .modelNotPrepared: "The transcription model isn't loaded yet."
        case .emptyAudio: "No audio was captured."
        case .unsupported(let message): message
        }
    }
}

// MARK: - Protocol

/// An on-device speech-to-text backend that manages a model lifecycle.
///
/// Audio is always 16 kHz mono Float32 (see `AudioCaptureEngine`).
public protocol TranscriptionEngine: Sendable {
    var id: TranscriptionEngineID { get }
    var displayName: String { get }
    var isLocal: Bool { get }
    var availableModels: [TranscriptionModel] { get }

    /// Download (first run only) and load the model into memory. `progress`
    /// reports 0…1 during the download.
    func prepare(model: TranscriptionModel, progress: @Sendable @escaping (Double) -> Void) async throws

    /// Transcribe 16 kHz mono Float32 samples.
    func transcribe(samples: [Float], options: TranscriptionOptions) async throws -> TranscriptionResult

    /// Release any loaded model / resources.
    func unload() async
}

public extension TranscriptionEngine {
    var displayName: String { id.displayName }
    var isLocal: Bool { id.isLocal }
    var availableModels: [TranscriptionModel] { ModelCatalog.transcriptionModels(for: id) }
    func unload() async {}

    func prepare(model: TranscriptionModel) async throws {
        try await prepare(model: model, progress: { _ in })
    }
}
