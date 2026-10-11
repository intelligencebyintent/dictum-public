import SwiftUI

/// The inner content of the recording HUD, shared by the pill and notch
/// surfaces. Reflects the current `DictationController.State`.
struct HUDContent: View {
    var controller: DictationController
    /// Notch sits on a black shell, so prefer light ink; pill uses primary.
    var onDark: Bool = false

    /// The last non-idle state, kept so the HUD shows the completed frame (e.g.
    /// "Inserted") while it animates out, instead of flashing a lonely idle mic
    /// during the ~800 ms hide window.
    @State private var displayState: DictationController.State = .recording

    private var ink: Color { onDark ? .white : Theme.ink }
    private var muted: Color { onDark ? .white.opacity(0.6) : Theme.inkMuted }

    var body: some View {
        HStack(spacing: 10) {
            icon
                .font(.system(size: 13, weight: .semibold))
            detail
        }
        // Vertically center; let content size to Dynamic Type rather than a hard
        // height that would clip large accessibility text.
        .frame(minHeight: 22)
        // A generous, consistent width so the recording HUD reads as substantial
        // (not a thin sliver) and the surface doesn't jump in size between states.
        .frame(minWidth: 188)
        .onAppear { if controller.state.isVisible { displayState = controller.state } }
        .onChange(of: controller.state) { _, new in
            if new.isVisible { displayState = new }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        switch displayState {
        case .recording: controller.isHandsFree ? "Recording hands-free. Tap to stop." : "Recording"
        case .transcribing: "Transcribing"
        case .polishing: "Polishing"
        case .downloading(let p): "Downloading model \(Int(p * 100)) percent"
        case .inserting: "Inserted"
        case .error(let m): m
        case .idle, .listening: "Idle"
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch displayState {
        case .recording:
            // Steady — no pulse / color change. A lock means hands-free: the key
            // can be let go, and the next tap stops it.
            Image(systemName: controller.isHandsFree ? "lock.fill" : "mic.fill")
                .foregroundStyle(ink)
        case .transcribing, .polishing, .downloading:
            ProgressView()
                .controlSize(.small)
                .tint(ink)
        case .inserting:
            Image(systemName: "checkmark")
                .foregroundStyle(ink)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(ink)
        case .idle, .listening:
            Image(systemName: "mic")
                .foregroundStyle(muted)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch displayState {
        case .recording:
            WaveformView(levels: controller.levels, barCount: 28, tint: ink)
                .frame(width: 168)
        case .transcribing:
            label("Transcribing…")
        case .polishing:
            label("Polishing…")
        case .downloading(let progress):
            label("Downloading model \(Int(progress * 100))%")
        case .inserting:
            label("Inserted")
        case .error(let message):
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(muted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 240, alignment: .leading)
        case .idle, .listening:
            EmptyView()
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(muted)
            .fixedSize(horizontal: true, vertical: false)
    }
}
