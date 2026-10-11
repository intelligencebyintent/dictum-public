import SwiftUI
import AppKit

/// A quick voice-notes surface. Dictate into it with your hotkey (the text is
/// pasted into the focused editor, which is this window when it's frontmost).
struct ScratchpadView: View {
    @AppStorage("scratchpadText") private var text = ""

    var body: some View {
        VStack(spacing: 0) {
            TextEditor(text: $text)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(10)

            Divider()

            HStack(spacing: 8) {
                Text("Dictate here with your push-to-talk key.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Copy") { copyAll() }
                    .disabled(text.isEmpty)
                Button("Clear") { text = "" }
                    .disabled(text.isEmpty)
            }
            .padding(10)
        }
        .frame(minWidth: 380, minHeight: 300)
    }

    private func copyAll() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
