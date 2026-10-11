import SwiftUI
import MurmurKit

/// First-run walkthrough. Monochrome, immersive. Grants the permissions the core
/// loop needs, downloads the offline model, and explains the two ways to dictate.
/// Each permission row deep-links to the right System Settings pane; statuses
/// refresh when the app reactivates.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    var permissions: PermissionsManager
    var onFinish: () -> Void

    @State private var modelState: ModelState = .idle
    private enum ModelState: Equatable { case idle, working(Double), ready, failed(String) }

    var body: some View {
        VStack(spacing: 0) {
            // Scroll the header + rows so large Dynamic Type / many rows never clip
            // the action button, which stays pinned at the bottom.
            ScrollView {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: 12) {
                        permissionRows
                    }
                    .padding(24)
                }
            }

            Divider()

            Button(action: onFinish) {
                Text(permissions.coreGranted ? "Start dictating" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(.primary)
            .padding(24)
        }
        .frame(minWidth: 460, idealWidth: 460, minHeight: 560, idealHeight: 660)
        .background(.background)
        .onAppear {
            if appState.registry.isCurrentEnginePrepared { modelState = .ready }
        }
    }

    @ViewBuilder
    private var permissionRows: some View {
        Group {
            PermissionRow(
                    icon: "mic.fill",
                    title: "Microphone",
                    description: "Record your voice. Required.",
                    status: permissions.microphone,
                    action: { Task { await permissions.requestMicrophone() } },
                    openSettings: { permissions.openSettings(.microphone) }
                )
                PermissionRow(
                    icon: "accessibility",
                    title: "Accessibility",
                    description: "Paste transcribed text into any app. Required.",
                    status: permissions.accessibility,
                    action: { permissions.requestAccessibility() },
                    openSettings: { permissions.openSettings(.accessibility) }
                )
                PermissionRow(
                    icon: "keyboard",
                    title: "Input Monitoring",
                    description: "Needed for the Right ⌘ hold-to-talk key. (The ⌃⌥D shortcut works without it.)",
                    status: permissions.inputMonitoring,
                    action: { permissions.requestInputMonitoring() },
                    openSettings: { permissions.openSettings(.inputMonitoring) }
                )

                if appState.settings.transcriptionEngineID.isLocal {
                    modelRow
                }

            Text("Then **hold Right ⌘** and speak, or **double-tap** it to keep recording hands-free. ⌃⌥D starts and stops hands-free dictation too. On macOS 27 both permissions live under Privacy & Security → Device Control and Data Access. If the hold key isn't detected after granting, toggle Dictum off and back on there — macOS sometimes keeps a stale entry.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.primary)
                .padding(.top, 40)
            Text("Welcome to Dictum")
                .font(.title.weight(.semibold))
            Text("Grant microphone + accessibility, download the offline model, and you're ready to dictate anywhere.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    /// Downloads + loads the on-device model (the default, no API key needed) into
    /// the shared registry, so the dictation pipeline reuses it instantly.
    @ViewBuilder
    private var modelRow: some View {
        let engine = appState.settings.transcriptionEngineID
        let model = appState.settings.selectedTranscriptionModel(for: engine)

        HStack(spacing: 14) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 20))
                .frame(width: 34, height: 34)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Offline speech model").font(.headline)
                Text(modelSubtitle(model)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            switch modelState {
            case .idle:
                Button("Download") { downloadModel() }
            case .working(let progress):
                HStack(spacing: 6) {
                    ProgressView(value: progress).frame(width: 64)
                    Text("\(Int(progress * 100))%").font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            case .ready:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            case .failed:
                Button("Retry") { downloadModel() }
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func modelSubtitle(_ model: TranscriptionModel) -> String {
        switch modelState {
        case .failed(let message): return message
        case .ready: return "Ready — runs 100% on-device."
        default:
            let size = model.approxSizeMB.map { "~\($0) MB. " } ?? ""
            return "\(size)Downloads once, then transcribes offline with no API key."
        }
    }

    private func downloadModel() {
        modelState = .working(0)
        Task {
            do {
                _ = try await appState.registry.preparedTranscriptionEngine { progress in
                    Task { @MainActor in
                        if case .working = modelState { modelState = .working(progress) }
                    }
                }
                modelState = .ready
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                modelState = .failed(message)
            }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let status: PermissionStatus
    let action: () -> Void
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 34, height: 34)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(description).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            switch status {
            case .granted:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.title3)
            case .notDetermined:
                Button("Grant", action: action)
            case .denied:
                Button("Open Settings", action: openSettings)
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }
}
