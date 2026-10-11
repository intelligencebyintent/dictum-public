import SwiftUI
import ServiceManagement
import MurmurKit

struct GeneralPane: View {
    @Environment(AppState.self) private var appState
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private let languages: [(name: String, code: String?)] = [
        ("Auto-detect", nil),
        ("English", "en"), ("Spanish", "es"), ("French", "fr"), ("German", "de"),
        ("Italian", "it"), ("Portuguese", "pt"), ("Dutch", "nl"), ("Polish", "pl"),
        ("Russian", "ru"), ("Japanese", "ja"),
    ]

    var body: some View {
        @Bindable var settings = appState.settings
        Form {
            Section("Dictation") {
                Picker("Language", selection: Binding(
                    get: { settings.language },
                    set: { settings.language = $0 }
                )) {
                    ForEach(languages, id: \.code) { Text($0.name).tag($0.code) }
                }
            }

            Section("Appearance") {
                Picker("Recording HUD", selection: $settings.hudStyle) {
                    ForEach(HUDStyle.allCases) { Text($0.displayName).tag($0) }
                }
                Text("Automatic shows the notch on MacBooks with one and a floating pill elsewhere.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch Dictum at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        setLaunchAtLogin(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.settings.error("Launch-at-login toggle failed: \(error.localizedDescription)")
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
