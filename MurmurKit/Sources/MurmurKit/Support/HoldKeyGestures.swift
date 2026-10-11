import Foundation

/// Which hold key a press came from.
public enum HoldKeyRole: Sendable, Equatable {
    /// The dictation key (Right ⌘ by default): hold to talk, double-tap for hands-free.
    case dictation
    /// The high-accuracy key (Right ⌥ by default): hold to talk with the
    /// high-accuracy engine for that one utterance.
    case highAccuracy
}

/// What the app should do in response to hold-key input.
public enum GestureAction: Equatable, Sendable {
    case none
    /// A hold key went down. Start capturing now, so the first word isn't
    /// clipped, but keep the HUD hidden: the press may still turn out to be a
    /// tap or part of a shortcut.
    case startCapture(highAccuracy: Bool)
    /// The key has been held for the minimum time, so this is a real dictation.
    case confirm
    /// Released after a real hold, or tapped to stop a hands-free recording:
    /// transcribe and insert.
    case finish
    /// A short tap, or the key was used as a shortcut modifier: throw the audio
    /// away and show nothing.
    case discard
    /// The second tap of a double-tap: keep recording until the next tap or
    /// silence.
    case handsFree
}

/// The modifier-key gestures (hold, double-tap, high-accuracy hold) as a pure
/// state machine, so the timing rules are unit
/// tested rather than buried in event-tap callbacks.
///
/// - Hold the dictation key: record while held, transcribe on release.
/// - Double-tap it: record hands-free until the next tap (or silence, which
///   the controller handles).
/// - Hold the high-accuracy key: same as holding, with the high-accuracy engine.
/// - Presses shorter than `minimumHold` do nothing (the first tap of a
///   double-tap is one of these).
/// - A key used as a shortcut modifier (another key, modifier, or click while
///   it's down, or another modifier already down when it's pressed) does nothing.
///
/// Times are seconds on any monotonic clock.
public struct HoldKeyGestures: Sendable {
    public struct Timing: Sendable {
        /// Presses shorter than this are ignored.
        public var minimumHold: TimeInterval
        /// Longest gap between releasing the first tap and pressing the second.
        public var doubleTapGap: TimeInterval

        public init(minimumHold: TimeInterval = 0.25, doubleTapGap: TimeInterval = 0.4) {
            self.minimumHold = minimumHold
            self.doubleTapGap = doubleTapGap
        }
    }

    private enum Phase: Equatable {
        case idle
        case held(HoldKeyRole, since: TimeInterval, confirmed: Bool, secondTap: Bool)
        case awaitingSecondTap(releasedAt: TimeInterval)
        /// The key is down but isn't dictating (shortcut use, or it just stopped
        /// a hands-free recording). Wait for its release.
        case ignoringUntilRelease(HoldKeyRole)
    }

    public let timing: Timing
    private var phase: Phase = .idle

    public init(timing: Timing = Timing()) {
        self.timing = timing
    }

    /// True while a hold key is down and capturing (provisionally or confirmed).
    public var isHolding: Bool {
        if case .held = phase { return true }
        return false
    }

    /// A hold key went down.
    /// - Parameters:
    ///   - recording: whether a dictation is already recording (hands-free, or
    ///     started from a shortcut or the menu). A press then stops it.
    ///   - chorded: whether another modifier was already down, as in ⇧⌘.
    public mutating func keyDown(_ role: HoldKeyRole, at now: TimeInterval, recording: Bool, chorded: Bool) -> GestureAction {
        switch phase {
        case .held(let heldRole, _, _, _):
            // Both hold keys at once is a chord, not dictation.
            phase = .ignoringUntilRelease(heldRole)
            return .discard
        case .ignoringUntilRelease:
            return .none
        case .idle, .awaitingSecondTap:
            break
        }

        if chorded {
            phase = .ignoringUntilRelease(role)
            return .none
        }
        if recording {
            phase = .ignoringUntilRelease(role)
            return .finish
        }

        var secondTap = false
        if case .awaitingSecondTap(let releasedAt) = phase, role == .dictation,
           now - releasedAt <= timing.doubleTapGap {
            secondTap = true
        }
        phase = .held(role, since: now, confirmed: false, secondTap: secondTap)
        return .startCapture(highAccuracy: role == .highAccuracy)
    }

    /// A hold key came up.
    public mutating func keyUp(_ role: HoldKeyRole, at now: TimeInterval) -> GestureAction {
        switch phase {
        case let .held(heldRole, since, confirmed, secondTap) where heldRole == role:
            if confirmed || now - since >= timing.minimumHold {
                phase = .idle
                return .finish
            }
            if secondTap {
                phase = .idle
                return .handsFree
            }
            phase = role == .dictation ? .awaitingSecondTap(releasedAt: now) : .idle
            return .discard
        case .ignoringUntilRelease(let heldRole) where heldRole == role:
            phase = .idle
            return .none
        default:
            return .none
        }
    }

    /// Called once `minimumHold` has passed since a `.startCapture`. Stale
    /// calls (from an earlier press) are harmless: the hold time is re-checked.
    public mutating func holdElapsed(at now: TimeInterval) -> GestureAction {
        guard case let .held(role, since, false, secondTap) = phase,
              now - since >= timing.minimumHold - 0.001 else { return .none }
        phase = .held(role, since: since, confirmed: true, secondTap: secondTap)
        return .confirm
    }

    /// Any other key, modifier, or mouse button went down. While a hold key is
    /// down that means it's a shortcut modifier (⌘C, ⌘-click, ⌘-Tab), so drop
    /// the audio, even after the hold was confirmed.
    public mutating func otherInput() -> GestureAction {
        switch phase {
        case .held(let role, _, _, _):
            phase = .ignoringUntilRelease(role)
            return .discard
        case .awaitingSecondTap:
            phase = .idle
            return .none
        case .idle, .ignoringUntilRelease:
            return .none
        }
    }

    /// Forget any press in progress (the event tap stopped).
    public mutating func reset() {
        phase = .idle
    }
}
