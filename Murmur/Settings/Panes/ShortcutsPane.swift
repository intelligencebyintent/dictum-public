import SwiftUI
import KeyboardShortcuts
import MurmurKit

struct ShortcutsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings
        Form {
            Section("Hold keys") {
                Picker("Dictate", selection: $settings.pushToTalkKey) {
                    ForEach(PushToTalkKey.allCases) { Text($0.displayName).tag($0) }
                }
                Text("Hold to record, release to insert. Double-tap to record hands-free until you tap again or stop talking for 3 seconds. Presses under a quarter second, and presses used in a shortcut like ⌘C, are ignored.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("High-accuracy dictation", selection: $settings.highAccuracyKey) {
                    Text("Off").tag(PushToTalkKey?.none)
                    ForEach(PushToTalkKey.allCases) { Text($0.displayName).tag(PushToTalkKey?.some($0)) }
                }
                Text(highAccuracyNote(settings))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                LabeledContent("Start or stop hands-free") {
                    KeyboardShortcuts.Recorder(for: .toggleDictation)
                }
                LabeledContent("Command Mode") {
                    KeyboardShortcuts.Recorder(for: .commandMode)
                }
                LabeledContent("Paste last result") {
                    KeyboardShortcuts.Recorder(for: .pasteLast)
                }
                LabeledContent("Cancel while dictating") {
                    HStack {
                        KeyboardShortcuts.Recorder(for: .cancelDictation)
                        Button("Use Esc") { KeyboardShortcuts.reset(.cancelDictation) }
                    }
                }
                Text("Command Mode: select text, press the shortcut, say what to change (\"make this formal\"), and press it again. Needs a local LLM. Cancel is claimed only while Dictum is recording or working, so Esc behaves normally otherwise.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Scratchpad") {
                LabeledContent("Open scratchpad") {
                    KeyboardShortcuts.Recorder(for: .openScratchpad)
                }
            }

            Section {
                Text("Hold keys need Accessibility and Input Monitoring (System Settings → Privacy & Security → Device Control and Data Access). Shortcuts work with Accessibility alone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
    }

    private func highAccuracyNote(_ settings: AppSettings) -> String {
        if let key = settings.highAccuracyKey, key == settings.pushToTalkKey {
            return "Off while it's the same key as Dictate."
        }
        return "Hold to dictate one utterance with the high-accuracy engine. Until a high-accuracy engine is added, it uses Parakeet."
    }
}
