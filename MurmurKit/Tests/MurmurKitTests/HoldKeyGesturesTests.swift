import Foundation
import Testing
@testable import MurmurKit

/// The hotkey table's modifier-key rules: hold to talk, double-tap for
/// hands-free, ignore presses under 250 ms, and ignore the key when it's a
/// shortcut modifier. Pure timing logic; no event tap or microphone.
@Suite("Hold-key gestures")
struct HoldKeyGesturesTests {
    private func press(_ g: inout HoldKeyGestures, _ role: HoldKeyRole = .dictation, at t: TimeInterval,
                       recording: Bool = false, chorded: Bool = false) -> GestureAction {
        g.keyDown(role, at: t, recording: recording, chorded: chorded)
    }

    @Test func holdStartsAtOnceConfirmsAt250msAndFinishesOnRelease() {
        var g = HoldKeyGestures()
        #expect(press(&g, at: 0) == .startCapture(highAccuracy: false))
        #expect(g.holdElapsed(at: 0.25) == .confirm)
        #expect(g.keyUp(.dictation, at: 2.0) == .finish)
    }

    @Test func releaseAfter250msFinishesEvenIfTheTimerIsLate() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        #expect(g.keyUp(.dictation, at: 0.3) == .finish)
        #expect(g.holdElapsed(at: 0.31) == .none)
    }

    @Test func tapUnder250msIsDiscarded() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        #expect(g.keyUp(.dictation, at: 0.24) == .discard)
    }

    @Test func doubleTapEntersHandsFreeAndTheNextTapFinishes() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        #expect(g.keyUp(.dictation, at: 0.1) == .discard)
        #expect(press(&g, at: 0.3) == .startCapture(highAccuracy: false))
        #expect(g.keyUp(.dictation, at: 0.4) == .handsFree)
        // Later, with the controller recording hands-free, one tap stops it…
        #expect(press(&g, at: 5.0, recording: true) == .finish)
        // …and its release does nothing.
        #expect(g.keyUp(.dictation, at: 5.1) == .none)
    }

    @Test func tapThenHoldIsPushToTalk() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        _ = g.keyUp(.dictation, at: 0.1)
        _ = press(&g, at: 0.3)
        #expect(g.holdElapsed(at: 0.55) == .confirm)
        #expect(g.keyUp(.dictation, at: 3.0) == .finish)
    }

    @Test func slowSecondTapIsJustAnotherTap() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        _ = g.keyUp(.dictation, at: 0.1)
        _ = press(&g, at: 0.1 + 0.41)
        #expect(g.keyUp(.dictation, at: 0.6) == .discard)
    }

    @Test func highAccuracyKeyHoldsButHasNoDoubleTap() {
        var g = HoldKeyGestures()
        #expect(press(&g, .highAccuracy, at: 0) == .startCapture(highAccuracy: true))
        #expect(g.keyUp(.highAccuracy, at: 0.1) == .discard)
        _ = press(&g, .highAccuracy, at: 0.2)
        #expect(g.keyUp(.highAccuracy, at: 0.3) == .discard)
        _ = press(&g, .highAccuracy, at: 1)
        #expect(g.holdElapsed(at: 1.25) == .confirm)
        #expect(g.keyUp(.highAccuracy, at: 2) == .finish)
    }

    // MARK: Shortcut use

    @Test func anotherKeyWhileHeldIsAShortcutEvenAfterConfirm() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        #expect(g.otherInput() == .discard)          // ⌘C
        #expect(g.holdElapsed(at: 0.25) == .none)    // no HUD later
        #expect(g.keyUp(.dictation, at: 0.4) == .none)

        _ = press(&g, at: 1)
        _ = g.holdElapsed(at: 1.25)
        #expect(g.otherInput() == .discard)          // slow ⌘-Tab
        #expect(g.keyUp(.dictation, at: 3) == .none)
    }

    @Test func chordedPressIsIgnored() {
        var g = HoldKeyGestures()
        #expect(press(&g, at: 0, chorded: true) == .none)   // ⇧ already down
        #expect(g.holdElapsed(at: 0.3) == .none)
        #expect(g.keyUp(.dictation, at: 1) == .none)
        #expect(press(&g, at: 2) == .startCapture(highAccuracy: false))
    }

    @Test func bothHoldKeysAtOnceIsAChord() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        #expect(press(&g, .highAccuracy, at: 0.1) == .discard)
        #expect(g.keyUp(.highAccuracy, at: 0.2) == .none)
        #expect(g.keyUp(.dictation, at: 0.5) == .none)
        #expect(press(&g, at: 1) == .startCapture(highAccuracy: false))
    }

    @Test func typingBetweenTapsBreaksTheDoubleTap() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0)
        _ = g.keyUp(.dictation, at: 0.1)
        _ = g.otherInput()
        _ = press(&g, at: 0.2)
        #expect(g.keyUp(.dictation, at: 0.3) == .discard)
    }

    @Test func otherInputWhileIdleOrHandsFreeDoesNothing() {
        var g = HoldKeyGestures()
        #expect(g.otherInput() == .none)
        _ = press(&g, at: 0); _ = g.keyUp(.dictation, at: 0.1)
        _ = press(&g, at: 0.2); _ = g.keyUp(.dictation, at: 0.3)   // hands-free
        #expect(g.otherInput() == .none)                            // typing while hands-free
    }

    @Test func staleTimerFromAnEarlierPressDoesNotConfirm() {
        var g = HoldKeyGestures()
        _ = press(&g, at: 0); _ = g.keyUp(.dictation, at: 0.1)
        _ = press(&g, at: 1.0)
        #expect(g.holdElapsed(at: 1.1) == .none)    // timer from the first press
        #expect(g.holdElapsed(at: 1.25) == .confirm)
    }

    // MARK: Key detection

    @Test func rightCommandReleaseRegistersWhileLeftCommandIsHeld() {
        let leftCmd = ModifierBits.command | ModifierBits.leftCommand
        let bothCmd = leftCmd | ModifierBits.rightCommand
        #expect(PushToTalkKey.rightCommand.isDown(inFlags: bothCmd))
        #expect(!PushToTalkKey.rightCommand.isDown(inFlags: leftCmd))
    }

    @Test func keyWithoutSideInformationFallsBackToTheGenericFlag() {
        #expect(PushToTalkKey.rightCommand.isDown(inFlags: ModifierBits.command))
        #expect(!PushToTalkKey.rightCommand.isDown(inFlags: 0))
    }

    @Test func otherModifiersMakeAChord() {
        let rightCmd = ModifierBits.command | ModifierBits.rightCommand
        #expect(!PushToTalkKey.rightCommand.otherModifiersDown(inFlags: rightCmd))
        #expect(PushToTalkKey.rightCommand.otherModifiersDown(inFlags: rightCmd | ModifierBits.shift | ModifierBits.leftShift))
        #expect(PushToTalkKey.rightCommand.otherModifiersDown(inFlags: rightCmd | ModifierBits.leftCommand))
        // Caps Lock (0x10000) and Fn don't count.
        #expect(!PushToTalkKey.rightCommand.otherModifiersDown(inFlags: rightCmd | 0x10000 | ModifierBits.fn))
    }

    @Test func keyCodesMatchMacOS() {
        #expect(PushToTalkKey.rightCommand.keyCode == 54)
        #expect(PushToTalkKey.rightOption.keyCode == 61)
    }
}
