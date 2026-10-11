import SwiftUI

/// The floating-pill recording HUD — a Liquid Glass capsule that appears near
/// the screen edge during dictation. Used on non-notch displays or when the
/// user prefers the pill.
struct FlowBarView: View {
    var controller: DictationController

    @Environment(\.colorScheme) private var colorScheme
    @State private var shown = false

    /// A hairline rim on the glass capsule: a faint white top-highlight on dark
    /// glass, a faint dark separator on light glass. A fixed white stroke is
    /// invisible (and the wrong direction) in light mode.
    private var rimColor: Color {
        colorScheme == .dark ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    var body: some View {
        HUDContent(controller: controller)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .glassSurface(in: Capsule())
            .overlay(
                Capsule().strokeBorder(rimColor, lineWidth: 0.5)
            )
            .fixedSize()
            .scaleEffect(shown ? 1 : 0.9, anchor: .bottom)
            .opacity(shown ? 1 : 0)
            .padding(8) // room for the panel's shadow
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) { shown = true }
            }
    }
}
