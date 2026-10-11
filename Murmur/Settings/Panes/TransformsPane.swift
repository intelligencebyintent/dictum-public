import SwiftUI
import KeyboardShortcuts
import MurmurKit

struct TransformsPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var settings = appState.settings
        Form {
            Section {
                Text("Bind a hotkey to rewrite the currently selected text with an instruction — like Wispr Flow's Transforms.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(settings.transforms.enumerated()), id: \.element.id) { index, _ in
                Section {
                    TextField("Name", text: $settings.transforms[index].name)
                    TextField("Instruction", text: $settings.transforms[index].prompt, axis: .vertical)
                        .lineLimit(1...4)
                    if index < KeyboardShortcuts.Name.transformSlots.count {
                        LabeledContent("Shortcut") {
                            KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.transformSlots[index])
                        }
                    }
                    Button("Remove", role: .destructive) {
                        settings.transforms.remove(at: index)
                    }
                }
            }

            if settings.transforms.count < TransformSlot.maxSlots {
                Section {
                    Button {
                        settings.transforms.append(TransformSlot(name: "New transform", prompt: ""))
                    } label: {
                        Label("Add transform", systemImage: "plus")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Transforms")
    }
}
