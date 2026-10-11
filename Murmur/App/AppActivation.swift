import AppKit

/// Manages the agent ↔ regular activation-policy flip. At rest Murmur is a
/// Dock-less menu-bar agent; while a real window (Settings, onboarding,
/// scratchpad) is open it becomes `.regular` so the window reliably comes to the
/// front and a Dock icon offers an obvious second way back in.
@MainActor
enum AppActivation {
    static func beginWindowSession() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Called after a window closes; reverts to agent mode once no ordinary
    /// windows remain visible.
    static func endWindowSessionSoon() {
        DispatchQueue.main.async {
            let hasOrdinaryWindow = NSApp.windows.contains { window in
                window.isVisible && window.canBecomeMain && !(window is FloatingHUDPanel)
            }
            if !hasOrdinaryWindow {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
