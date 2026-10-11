import Foundation

/// Known default models per engine/provider. Local engines auto-download these;
/// local LLM servers report their own list at runtime (see `LocalServerDetector`).
public enum ModelCatalog {

    // MARK: Transcription

    public static let parakeet: [TranscriptionModel] = [
        TranscriptionModel(id: "parakeet-tdt-0.6b-v3", displayName: "Parakeet TDT v3 (multilingual)", approxSizeMB: 600, isMultilingual: true),
        TranscriptionModel(id: "parakeet-tdt-0.6b-v2", displayName: "Parakeet TDT v2 (English)", approxSizeMB: 600, isMultilingual: false),
    ]

    public static func transcriptionModels(for id: TranscriptionEngineID) -> [TranscriptionModel] {
        switch id {
        case .parakeet: parakeet
        }
    }

    public static func defaultTranscriptionModel(for id: TranscriptionEngineID) -> TranscriptionModel {
        transcriptionModels(for: id).first
            ?? TranscriptionModel(id: "default", displayName: "Default")
    }

    // MARK: Chat (Polish / Command Mode)

    /// Apple's on-device model is the one model the system provides. Local
    /// servers report their models live, so they have no static catalog.
    /// Apple's model is the default (see `tools/cleanup-bakeoff`).
    public static func chatModels(for id: LLMProviderID) -> [LLMModel] {
        switch id {
        case .appleOnDevice: [appleOnDevice]
        case .lmStudio, .ollama: []
        }
    }

    public static let appleOnDevice = LLMModel(id: "apple-on-device", displayName: "Apple on-device model")
}
