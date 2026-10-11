import Foundation
import MurmurKit
import Observation
import SwiftData

/// Composition root shared between the AppKit shell and SwiftUI views. Owns the
/// long-lived services (settings, permissions, engine registry) and a
/// reference to the live `DictationController` for status/Settings UI.
@MainActor
@Observable
final class AppState {
    let version: String
    let settings: AppSettings
    let permissions: PermissionsManager
    let registry: EngineRegistry
    let modelContainer: ModelContainer
    /// True when persistence fell back to an in-memory store (the on-disk store
    /// couldn't be opened). History/Dictionary/Snippets won't survive relaunch;
    /// surfaced to the user rather than crashing.
    let persistenceIsEphemeral: Bool

    /// Set by `AppDelegate` once the pipeline is built.
    var dictation: DictationController?

    init() {
        self.version = Bundle.main.shortVersion
        let settings = AppSettings()
        self.settings = settings
        self.permissions = PermissionsManager()
        self.registry = EngineRegistry(settings: settings)

        // History/Dictionary/Snippets are not core to dictation, so a failed or
        // corrupted on-disk store must never brick the app. Try the persistent
        // store; on failure fall back to an in-memory one so the app still runs.
        let schema: [any PersistentModel.Type] = [HistoryItem.self, DictionaryEntry.self, Snippet.self]
        let storeConfig = ModelConfiguration(schema: Schema(schema), url: ModelStorage.swiftDataStoreURL)
        if let container = try? ModelContainer(for: Schema(schema), configurations: [storeConfig]) {
            self.modelContainer = container
            self.persistenceIsEphemeral = false
        } else {
            Log.app.error("Persistent SwiftData store unavailable; falling back to in-memory store")
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            // An in-memory container with a valid schema is effectively infallible;
            // if even this fails the process genuinely can't continue.
            self.modelContainer = try! ModelContainer(
                for: Schema(schema),
                configurations: [config]
            )
            self.persistenceIsEphemeral = true
        }
    }
}

extension Bundle {
    /// `CFBundleShortVersionString`, falling back to "0.0.0" in non-bundle contexts.
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }
}
