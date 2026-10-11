import Foundation

/// Top-level namespace + metadata for Dictum's engine package. (The module keeps
/// its upstream name, `MurmurKit`, to keep merges from Murmur simple.)
///
/// `MurmurKit` holds the engine-agnostic dictation pipeline: the on-device
/// transcription engine, local LLM "Polish" providers, audio capture, settings,
/// and data models. It is UI-framework-free so it can be exercised headlessly
/// with `swift test`.
public enum Murmur {
    /// Marketing version, kept in sync with the app target's `MARKETING_VERSION`.
    public static let version = "0.1.0"
}
