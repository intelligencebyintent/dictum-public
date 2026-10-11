import SwiftUI

/// Murmur's monochromatic design tokens. Built only from system semantic colors
/// + grayscale so the whole UI is monochrome and adapts to light/dark and
/// accessibility settings automatically. No brand hue.
enum Theme {
    // Text
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color(nsColor: .tertiaryLabelColor)

    // Surfaces
    static let separator = Color(nsColor: .separatorColor)
    static let controlBackground = Color(nsColor: .controlBackgroundColor)
    static let windowBackground = Color(nsColor: .windowBackgroundColor)

    // HUD (monochrome ink on glass / black)
    static let ink = Color.primary
    static let inkMuted = Color.secondary
    static let recording = Color.primary   // monochrome; pulse conveys state, not color

    // Radii
    static let cardRadius: CGFloat = 16
    static let pillRadius: CGFloat = 22
}
