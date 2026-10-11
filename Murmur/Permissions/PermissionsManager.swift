import AppKit
import AVFoundation
import ApplicationServices
import IOKit.hid
import MurmurKit

enum PermissionStatus: Sendable {
    case granted, denied, notDetermined

    var isGranted: Bool { self == .granted }
}

/// The privacy permissions Murmur needs, with deep links into the right
/// System Settings panes. Re-checked when the app reactivates (TCC grants can't
/// be observed live).
@MainActor
@Observable
final class PermissionsManager {
    private(set) var microphone: PermissionStatus = .notDetermined
    private(set) var accessibility: PermissionStatus = .notDetermined
    private(set) var inputMonitoring: PermissionStatus = .notDetermined

    /// The minimum needed for the core loop: record (mic) + paste (accessibility).
    /// The ⌃⌥D toggle works with just these — Input Monitoring is only for the
    /// modifier hold key, so it's not required here.
    var coreGranted: Bool {
        microphone.isGranted && accessibility.isGranted
    }

    init() {
        refresh()
    }

    func refresh() {
        microphone = Self.microphoneStatus()
        accessibility = AXIsProcessTrusted() ? .granted : .notDetermined
        inputMonitoring = Self.inputMonitoringStatus()
    }

    // MARK: Requests

    func requestMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
    }

    /// Prompts for Accessibility (shows the system "open Settings" alert once).
    func requestAccessibility() {
        // Documented key string for kAXTrustedCheckOptionPrompt (the imported
        // global is not concurrency-safe under Swift 6).
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        refresh()
    }

    // MARK: Deep links

    enum Pane: String {
        case microphone = "Privacy_Microphone"
        case accessibility = "Privacy_Accessibility"
        case inputMonitoring = "Privacy_ListenEvent"
    }

    func openSettings(_ pane: Pane) {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Status helpers

    private static func microphoneStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private static func inputMonitoringStatus() -> PermissionStatus {
        switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
        case kIOHIDAccessTypeGranted: .granted
        case kIOHIDAccessTypeDenied: .denied
        default: .notDetermined
        }
    }
}
