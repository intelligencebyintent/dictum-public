import AppKit
import SwiftUI

/// Self-managed Settings window. The SwiftUI `Settings` scene + the
/// `showSettingsWindow:` selector don't reliably open for a menu-bar agent, so
/// we host `SettingsRootView` in our own `NSWindow` (like onboarding/scratchpad).
@MainActor
final class SettingsWindowController {
    private let appState: AppState
    private var window: NSWindow?

    init(appState: AppState) {
        self.appState = appState
    }

    func show() {
        if window == nil {
            let root = SettingsRootView()
                .environment(appState)
                .modelContainer(appState.modelContainer)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Dictum Settings"
            window.contentView = NSHostingView(rootView: root)
            window.center()
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("DictumSettings")
            self.window = window
        }

        AppActivation.beginWindowSession()
        window?.makeKeyAndOrderFront(nil)
    }
}
