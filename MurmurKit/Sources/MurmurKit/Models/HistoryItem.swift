import Foundation
import SwiftData

/// A past dictation, persisted with SwiftData for the History pane.
@Model
public final class HistoryItem {
    public var id: UUID
    public var date: Date
    public var rawText: String
    public var polishedText: String
    public var engineID: String
    public var appName: String?
    public var durationMs: Int?

    public init(
        date: Date = .now,
        rawText: String,
        polishedText: String,
        engineID: String,
        appName: String? = nil,
        durationMs: Int? = nil
    ) {
        self.id = UUID()
        self.date = date
        self.rawText = rawText
        self.polishedText = polishedText
        self.engineID = engineID
        self.appName = appName
        self.durationMs = durationMs
    }

    /// The text that was actually inserted (polished if present, else raw).
    public var insertedText: String {
        polishedText.isEmpty ? rawText : polishedText
    }
}
