import AppKit
import MurmurKit

/// Watches the modifier-only hold keys (Right ⌘ for dictation, Right ⌥ for
/// high accuracy by default) with a listen-only `CGEventTap`, and reports
/// whether anything else was pressed while one is down, which means the key is
/// being used as a shortcut modifier (⌘C, ⌘-click, ⌘-Tab).
///
/// Why a tap and not KeyboardShortcuts / Carbon: those fire on a non-modifier
/// key + modifiers and can't represent "hold Right ⌘ alone". Only the raw
/// event stream gives press *and* release of a modifier-only key.
///
/// Other keys are only checked for "was something else pressed"; key codes
/// and characters are never stored or logged.
///
/// Requires Accessibility + Input Monitoring. `tapCreate` returns nil until
/// granted, surfaced as `HoldKeyError.permissionRequired`.
@MainActor
final class HoldKeyTap {
    enum HoldKeyError: Error { case permissionRequired }

    /// A hold key changed: role, whether it's now down, and (on press) whether
    /// another modifier was already down.
    var onKey: (@MainActor (HoldKeyRole, _ down: Bool, _ chorded: Bool) -> Void)?
    /// Any other key, modifier, or mouse button went down.
    var onOtherInput: (@MainActor () -> Void)?

    private var dictationKey: PushToTalkKey
    private var highAccuracyKey: PushToTalkKey?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keysDown: Set<PushToTalkKey> = []

    private static let capsLockKeyCode: Int64 = 57

    init(dictationKey: PushToTalkKey, highAccuracyKey: PushToTalkKey?) {
        self.dictationKey = dictationKey
        self.highAccuracyKey = highAccuracyKey
    }

    var isRunning: Bool { tap != nil }

    func start() throws {
        guard tap == nil else { return }

        let types: [CGEventType] = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: holdKeyEventCallback,
            userInfo: userInfo
        ) else {
            throw HoldKeyError.permissionRequired
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        Log.hotkey.info("Hold-key tap started (dictation \(self.dictationKey.rawValue, privacy: .public), high accuracy \(self.highAccuracyKey?.rawValue ?? "off", privacy: .public))")
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
        keysDown = []
    }

    func updateKeys(dictation: PushToTalkKey, highAccuracy: PushToTalkKey?) {
        dictationKey = dictation
        highAccuracyKey = highAccuracy
        keysDown = []
    }

    /// Re-enable after the system disables the tap (slow callback / user input).
    fileprivate func reenable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.hotkey.warning("Hold-key tap re-enabled after system disable")
    }

    fileprivate func handle(type: CGEventType, flags: UInt64, keyCode: Int64) {
        guard type == .flagsChanged else {
            onOtherInput?()   // a key or mouse button
            return
        }

        let roles: [(PushToTalkKey, HoldKeyRole)] = [(dictationKey, .dictation)]
            + (highAccuracyKey.map { [($0, .highAccuracy)] } ?? [])
        guard let (key, role) = roles.first(where: { $0.0.keyCode == keyCode }) else {
            if keyCode != Self.capsLockKeyCode { onOtherInput?() }   // ⇧, ⌃, the other ⌘…
            return
        }

        let down = key.isDown(inFlags: flags)
        guard down != keysDown.contains(key) else { return }
        if down { keysDown.insert(key) } else { keysDown.remove(key) }
        onKey?(role, down, down && key.otherModifiersDown(inFlags: flags))
    }
}

/// C callback for the event tap. Runs on the main run loop; bounces into the
/// actor-isolated handler. Always returns the event unmodified (listen-only).
private func holdKeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<HoldKeyTap>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        MainActor.assumeIsolated { tap.reenable() }
    default:
        let flags = event.flags.rawValue
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        MainActor.assumeIsolated { tap.handle(type: type, flags: flags, keyCode: keyCode) }
    }
    return Unmanaged.passUnretained(event)
}
