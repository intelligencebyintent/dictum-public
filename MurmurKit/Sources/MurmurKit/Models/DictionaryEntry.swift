import Foundation
import SwiftData

/// A custom vocabulary term. With no `replacement`, it's a spelling/vocab hint
/// (injected into the transcription prompt + Polish prompt). With a
/// `replacement`, it's a literal substitution applied to the final text.
@Model
public final class DictionaryEntry {
    public var id: UUID
    public var phrase: String
    public var replacement: String?
    public var createdAt: Date

    public init(phrase: String, replacement: String? = nil, createdAt: Date = .now) {
        self.id = UUID()
        self.phrase = phrase
        self.replacement = replacement
        self.createdAt = createdAt
    }
}

/// A voice text-expansion: when the spoken `trigger` appears in a transcript,
/// it's replaced with `expansion` (e.g. "my email" → an address).
@Model
public final class Snippet {
    public var id: UUID
    public var trigger: String
    public var expansion: String
    public var createdAt: Date

    public init(trigger: String, expansion: String, createdAt: Date = .now) {
        self.id = UUID()
        self.trigger = trigger
        self.expansion = expansion
        self.createdAt = createdAt
    }
}
