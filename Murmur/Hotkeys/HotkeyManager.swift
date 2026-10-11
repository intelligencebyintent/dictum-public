import KeyboardShortcuts
import MurmurKit

/// User-customizable global shortcuts (normal key + modifier combos) via the
/// KeyboardShortcuts library. Complements `HoldKeyTap`, which handles the
/// modifier-only hold keys this library can't express. `default:` only seeds
/// names the user hasn't changed.
extension KeyboardShortcuts.Name {
    /// Start or stop hands-free dictation. Works without Input Monitoring.
    static let toggleDictation = Self("toggleDictation", default: .init(.d, modifiers: [.control, .option]))
    /// Cancel a dictation in progress. Only claimed while dictating; see
    /// `HotkeyManager.cancelArmed`.
    static let cancelDictation = Self("cancelDictation", default: .init(.escape))
    /// Command Mode: speak an instruction that rewrites the selection.
    static let commandMode = Self("commandMode", default: .init(.c, modifiers: [.control, .option]))
    /// Insert the last result again.
    static let pasteLast = Self("pasteLast", default: .init(.v, modifiers: [.control, .option]))
    /// Open the Scratchpad notes window.
    static let openScratchpad = Self("openScratchpad")

    /// Eight Transform slots.
    static let transformSlots: [Self] = (1...8).map { Self("transform\($0)") }
}

@MainActor
final class HotkeyManager {
    var onToggleDictation: (@MainActor () -> Void)?
    var onCancel: (@MainActor () -> Void)?
    var onCommandMode: (@MainActor () -> Void)?
    var onPasteLast: (@MainActor () -> Void)?
    var onScratchpad: (@MainActor () -> Void)?
    var onTransform: (@MainActor (Int) -> Void)?

    func register() {
        KeyboardShortcuts.onKeyDown(for: .toggleDictation) { [weak self] in self?.onToggleDictation?() }
        KeyboardShortcuts.onKeyDown(for: .commandMode) { [weak self] in self?.onCommandMode?() }
        KeyboardShortcuts.onKeyDown(for: .pasteLast) { [weak self] in self?.onPasteLast?() }
        KeyboardShortcuts.onKeyDown(for: .openScratchpad) { [weak self] in self?.onScratchpad?() }

        for (index, name) in KeyboardShortcuts.Name.transformSlots.enumerated() {
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in self?.onTransform?(index) }
        }
    }

    /// The cancel shortcut (Esc) is registered only while a dictation is in
    /// progress, so Esc works normally in every app the rest of the time. A
    /// registered hotkey is consumed, so the app under the HUD doesn't also
    /// see the Esc.
    var cancelArmed = false {
        didSet {
            guard cancelArmed != oldValue else { return }
            if cancelArmed {
                KeyboardShortcuts.onKeyDown(for: .cancelDictation) { [weak self] in self?.onCancel?() }
            } else {
                KeyboardShortcuts.removeHandler(for: .cancelDictation)
            }
        }
    }
}
