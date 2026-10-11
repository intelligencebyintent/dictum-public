import SwiftUI

struct AboutPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Dictum")
                .font(.largeTitle.weight(.semibold))
            Text("Version \(appState.version)")
                .foregroundStyle(.secondary)
            Text("Private, on-device dictation. Audio and text never leave this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Text("Based on Murmur by Robert Courson · MIT License")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("About")
    }
}
