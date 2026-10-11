import AppIntents

/// Bridge so App Intents (which run in-process) can reach the live controllers.
@MainActor
enum MurmurIntentBridge {
    static weak var dictation: DictationController?
    static weak var scratchpad: ScratchpadController?
}

struct ToggleDictationIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Dictation"
    static let description = IntentDescription("Start or stop hands-free dictation.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        await MainActor.run { MurmurIntentBridge.dictation?.toggle() }
        return .result()
    }
}

struct OpenScratchpadIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Scratchpad"
    static let description = IntentDescription("Open Dictum's scratchpad for quick voice notes.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { MurmurIntentBridge.scratchpad?.show() }
        return .result()
    }
}

struct MurmurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleDictationIntent(),
            phrases: ["Toggle dictation in \(.applicationName)"],
            shortTitle: "Toggle Dictation",
            systemImageName: "mic"
        )
        AppShortcut(
            intent: OpenScratchpadIntent(),
            phrases: ["Open \(.applicationName) scratchpad"],
            shortTitle: "Open Scratchpad",
            systemImageName: "note.text"
        )
    }
}
