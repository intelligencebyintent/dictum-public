import Foundation
import MurmurKit

/// Connects the hold-key tap to the dictation controller through the
/// `HoldKeyGestures` rules: hold to talk, double-tap for hands-free, the
/// high-accuracy key, the 250 ms minimum, and shortcut detection.
@MainActor
final class HoldKeyRouter {
    private let tap: HoldKeyTap
    private let controller: DictationController
    private let settings: AppSettings
    private var gestures = HoldKeyGestures()
    private var holdTimer: Task<Void, Never>?

    init(controller: DictationController, settings: AppSettings) {
        self.controller = controller
        self.settings = settings
        tap = HoldKeyTap(dictationKey: settings.pushToTalkKey, highAccuracyKey: settings.effectiveHighAccuracyKey)
        tap.onKey = { [weak self] role, down, chorded in self?.handleKey(role, down: down, chorded: chorded) }
        tap.onOtherInput = { [weak self] in
            guard let self else { return }
            self.apply(self.gestures.otherInput())
        }
        observeKeySettings()
    }

    var isRunning: Bool { tap.isRunning }

    func start() throws { try tap.start() }

    func stop() {
        tap.stop()
        forgetPress()
    }

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    private func handleKey(_ role: HoldKeyRole, down: Bool, chorded: Bool) {
        let action = down
            ? gestures.keyDown(role, at: now, recording: controller.isRecording, chorded: chorded)
            : gestures.keyUp(role, at: now)
        apply(action)
    }

    private func apply(_ action: GestureAction) {
        switch action {
        case .none:
            return
        case .startCapture(let highAccuracy):
            controller.beginHold(highAccuracy: highAccuracy)
            scheduleHoldTimer()
        case .confirm:
            Log.hotkey.info("Hold confirmed")
            controller.confirmHold()
        case .finish:
            holdTimer?.cancel()
            controller.finish()
        case .discard:
            holdTimer?.cancel()
            controller.discardHold()
        case .handsFree:
            holdTimer?.cancel()
            Log.hotkey.info("Double-tap: hands-free")
            controller.continueHandsFree()
        }
    }

    private func scheduleHoldTimer() {
        holdTimer?.cancel()
        let delay = gestures.timing.minimumHold
        holdTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.apply(self.gestures.holdElapsed(at: self.now))
        }
    }

    /// Drop a press in progress (tap stopped, or the keys changed under it).
    private func forgetPress() {
        holdTimer?.cancel()
        if gestures.isHolding { controller.discardHold() }
        gestures.reset()
    }

    /// Keep the tap's keys in sync with Settings.
    private func observeKeySettings() {
        withObservationTracking {
            _ = settings.pushToTalkKey
            _ = settings.highAccuracyKey
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.forgetPress()
                self.tap.updateKeys(dictation: self.settings.pushToTalkKey, highAccuracy: self.settings.effectiveHighAccuracyKey)
                self.observeKeySettings()
            }
        }
    }
}
