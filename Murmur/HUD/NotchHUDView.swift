import SwiftUI

/// The notch-anchored recording HUD — a black shell shaped like the camera
/// housing that grows down from the top of the display. Used on notch displays
/// (or when the user forces the notch style). Follows the macos-notch skill:
/// pure-black shell, vertically-centered content, grow-from-top spring motion.
struct NotchHUDView: View {
    var controller: DictationController
    /// Safe-area top inset (the physical notch height) so content clears the camera.
    var topInset: CGFloat

    @State private var shown = false

    var body: some View {
        // The top portion sits behind the menu bar / camera housing (black on
        // black, so it merges); the content sits below that line.
        let topClearance = max(topInset, 24)
        HUDContent(controller: controller, onDark: true)
            .padding(.horizontal, 16)
            .padding(.top, topClearance + 5)
            .padding(.bottom, 10)
            .background(Color.black)
            .clipShape(NotchShape(topRadius: 0, bottomRadius: 20))
            .fixedSize()
            .scaleEffect(x: shown ? 1 : 0.92, y: shown ? 1 : 0.55, anchor: .top)
            .opacity(shown ? 1 : 0)
            .padding(.horizontal, 10) // shadow room
            .padding(.bottom, 12)
            .shadow(color: .black.opacity(0.5), radius: 6, y: 2)
            .onAppear {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { shown = true }
            }
    }
}
