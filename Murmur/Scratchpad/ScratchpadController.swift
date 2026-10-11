import AppKit
import SwiftUI

/// Owns the Scratchpad window. Activates the app + focuses the editor so
/// dictation (paste-based insertion) lands in the scratchpad.
@MainActor
final class ScratchpadController {
    private var window: NSWindow?

    func toggle() {
        if let window, window.isVisible {
            // close() (not orderOut) posts willCloseNotification, which lets
            // AppDelegate revert the app to a Dock-less .accessory agent. The
            // window is reused on the next show() (isReleasedWhenClosed = false).
            window.close()
        } else {
            show()
        }
    }

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 340),
                styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Scratchpad"
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.contentView = NSHostingView(rootView: ScratchpadView())
            window.center()
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("DictumScratchpad")
            self.window = window
        }
        AppActivation.beginWindowSession()
        window?.makeKeyAndOrderFront(nil)
    }
}
