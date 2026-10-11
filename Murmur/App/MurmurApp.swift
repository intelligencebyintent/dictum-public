import SwiftUI

/// Murmur — an open-source, local-first AI voice dictation app for macOS.
///
/// Runs as an `LSUIElement` menu-bar agent (no Dock icon). The status item,
/// floating HUD panels, and global hotkeys are owned imperatively by
/// `AppDelegate`; SwiftUI provides the Settings window.
@main
struct MurmurApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsRootView()
                .environment(appDelegate.appState)
                .modelContainer(appDelegate.appState.modelContainer)
        }
        .windowResizability(.contentSize)
    }
}
