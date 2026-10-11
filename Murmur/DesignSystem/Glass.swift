import SwiftUI

/// Liquid Glass helpers. The deployment target is macOS 26, so the glass APIs
/// are available unconditionally — no availability gates or material fallback.
/// Per the macOS design rules, glass is for chrome (HUD, toolbars, floating
/// controls) — never for content rows/cards.
extension View {
    /// Apply Liquid Glass clipped to `shape`.
    func glassSurface(in shape: some Shape = RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)) -> some View {
        glassEffect(.regular, in: shape)
    }

    /// Glass for an interactive control (subtle highlight on hover/press).
    func glassControl(in shape: some Shape = Capsule()) -> some View {
        glassEffect(.regular.interactive(), in: shape)
    }
}
