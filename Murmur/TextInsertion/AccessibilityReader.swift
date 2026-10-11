import AppKit
import ApplicationServices

/// Reads context from the focused app via the Accessibility API: the frontmost
/// app (for context-aware Polish) and, where supported, the selected text (for
/// Command Mode). Reading is reliable across more apps than AX *writing*.
@MainActor
final class AccessibilityReader {
    struct FrontmostApp {
        let name: String?
        let bundleID: String?
    }

    func frontmostApp() -> FrontmostApp {
        let app = NSWorkspace.shared.frontmostApplication
        return FrontmostApp(name: app?.localizedName, bundleID: app?.bundleIdentifier)
    }

    /// The currently selected text via AX, or `nil` if the focused element
    /// doesn't expose it (common in web/Electron apps — fall back to ⌘C).
    func selectedText() -> String? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused,
              CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }

        // Safe: the type was just verified above.
        let element = focused as! AXUIElement
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String, !text.isEmpty else { return nil }
        return text
    }
}
