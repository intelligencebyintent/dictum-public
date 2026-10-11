import AppKit
import ApplicationServices

/// The UI element with keyboard focus, through the Accessibility API: used to
/// refuse password fields and for the insertion fallback.
@MainActor
struct FocusedElement {
    let element: AXUIElement

    /// A hung app shouldn't freeze Dictum. Set on the system-wide element, this
    /// timeout applies to every Accessibility call Dictum makes.
    private static let messagingTimeout: Float = 0.5

    static func current() -> FocusedElement? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messagingTimeout)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        // Safe: the type was just verified above.
        return FocusedElement(element: value as! AXUIElement)
    }

    /// Password fields (`NSSecureTextField`, web `<input type=password>`) report
    /// the secure-text-field subrole.
    var isSecureTextField: Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &value) == .success else { return false }
        return value as? String == kAXSecureTextFieldSubrole as String
    }

    /// Insert at the cursor by replacing the selection, and check that the
    /// field actually changed (many apps accept the call and ignore it).
    func insertText(_ text: String) async -> Bool {
        let before = fingerprint
        let status = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString)
        guard status == .success else { return false }
        guard let before else { return true }   // the field can't be checked; trust the call
        for _ in 0..<10 {
            if fingerprint != before { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    /// Character count and selection, which change whenever text goes in. Nil
    /// when the field exposes neither. Never reads the field's text.
    private var fingerprint: Fingerprint? {
        let count = intAttribute(kAXNumberOfCharactersAttribute)
        let range = selectedRange
        guard count != nil || range != nil else { return nil }
        return Fingerprint(characterCount: count, selectionLocation: range?.location, selectionLength: range?.length)
    }

    private struct Fingerprint: Equatable {
        let characterCount: Int?
        let selectionLocation: Int?
        let selectionLength: Int?
    }

    private func intAttribute(_ name: String) -> Int? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? Int
    }

    private var selectedRange: CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        // Safe: the type was just verified above.
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range
    }
}
