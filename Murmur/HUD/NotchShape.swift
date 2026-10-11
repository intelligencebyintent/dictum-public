import SwiftUI

/// The silhouette of a MacBook notch: flat top flush with the display edge,
/// small outward curves at the top corners, and larger rounded bottom corners,
/// so the HUD reads as "attached to the hardware". Radii are animatable so the
/// shape can grow on record.
struct NotchShape: Shape {
    var topRadius: CGFloat = 8
    var bottomRadius: CGFloat = 16

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = min(topRadius, rect.width / 2)
        let br = min(bottomRadius, rect.width / 2)

        // Flat top flush with the display edge (small rounding at top corners),
        // larger rounded bottom corners — reads as "hanging from the notch".
        // Stays entirely within bounds so nothing is clipped.
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - br, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - br),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        _ = tr // top kept square to merge with the black menu-bar/notch region
        return path
    }
}
