import Foundation

/// A modifier-only key usable for hold-to-talk. These can't be expressed as
/// normal shortcuts (there's no non-modifier key), so they're driven by a
/// `CGEventTap` on `flagsChanged` rather than the KeyboardShortcuts library.
public enum PushToTalkKey: String, Codable, CaseIterable, Sendable, Identifiable {
    case fn
    case rightOption
    case rightCommand
    case rightControl
    case leftControl

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .fn: "Fn (Globe)"
        case .rightOption: "Right Option ⌥"
        case .rightCommand: "Right Command ⌘"
        case .rightControl: "Right Control ⌃"
        case .leftControl: "Left Control ⌃"
        }
    }

    /// The virtual key code macOS reports in `flagsChanged` events for this key.
    public var keyCode: Int64 {
        switch self {
        case .fn: 63
        case .rightOption: 61
        case .rightCommand: 54
        case .rightControl: 62
        case .leftControl: 59
        }
    }

    /// Whether this key is down, given a `CGEventFlags` raw value. Uses the
    /// left/right device bits (IOKit's `NX_DEVICE…KEYMASK`) so releasing Right ⌘
    /// registers even while Left ⌘ is still held.
    public func isDown(inFlags raw: UInt64) -> Bool {
        if self == .fn { return raw & ModifierBits.fn != 0 }
        if raw & ModifierBits.allSided != 0 { return raw & sidedBit != 0 }
        return raw & genericBit != 0   // the event carries no left/right information
    }

    /// Whether a modifier other than this key (and other than Caps Lock and Fn)
    /// is down: pressing the key then is a chord like ⇧⌘, not dictation.
    public func otherModifiersDown(inFlags raw: UInt64) -> Bool {
        let others = ModifierBits.allSided & ~sidedBit
        if raw & ModifierBits.allSided != 0 { return raw & others != 0 }
        return raw & (ModifierBits.allGeneric & ~genericBit) != 0
    }

    private var sidedBit: UInt64 {
        switch self {
        case .fn: 0
        case .rightOption: ModifierBits.rightOption
        case .rightCommand: ModifierBits.rightCommand
        case .rightControl: ModifierBits.rightControl
        case .leftControl: ModifierBits.leftControl
        }
    }

    private var genericBit: UInt64 {
        switch self {
        case .fn: ModifierBits.fn
        case .rightOption: ModifierBits.option
        case .rightCommand: ModifierBits.command
        case .rightControl, .leftControl: ModifierBits.control
        }
    }
}

/// `CGEventFlags` bits, kept here so the key logic is testable without CoreGraphics.
enum ModifierBits {
    static let shift: UInt64 = 0x20000
    static let control: UInt64 = 0x40000
    static let option: UInt64 = 0x80000
    static let command: UInt64 = 0x100000
    static let fn: UInt64 = 0x800000
    static let allGeneric = shift | control | option | command

    static let leftControl: UInt64 = 0x01
    static let leftShift: UInt64 = 0x02
    static let rightShift: UInt64 = 0x04
    static let leftCommand: UInt64 = 0x08
    static let rightCommand: UInt64 = 0x10
    static let leftOption: UInt64 = 0x20
    static let rightOption: UInt64 = 0x40
    static let rightControl: UInt64 = 0x2000
    static let allSided = leftControl | leftShift | rightShift | leftCommand | rightCommand
        | leftOption | rightOption | rightControl
}

/// Which recording HUD surface to show.
public enum HUDStyle: String, Codable, CaseIterable, Sendable, Identifiable {
    case auto   // notch on notch-displays, pill otherwise
    case notch
    case pill

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: "Automatic"
        case .notch: "Notch"
        case .pill: "Floating pill"
        }
    }
}

/// A user-defined rewrite action bound to a hotkey slot (Wispr-style Transform).
public struct TransformSlot: Codable, Sendable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var prompt: String

    public init(id: UUID = UUID(), name: String, prompt: String) {
        self.id = id
        self.name = name
        self.prompt = prompt
    }

    /// The default starter set (users can edit/add up to `maxSlots`).
    public static let maxSlots = 8
    public static let defaults: [TransformSlot] = [
        TransformSlot(name: "Make concise", prompt: "Make this more concise while keeping the meaning."),
        TransformSlot(name: "Fix grammar", prompt: "Fix grammar, spelling, and punctuation. Keep the wording otherwise."),
        TransformSlot(name: "Professional", prompt: "Rewrite this in a clear, professional tone."),
        TransformSlot(name: "Bullet points", prompt: "Turn this into a clean bulleted list."),
    ]
}
