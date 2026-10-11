import Foundation

/// Where Dictum keeps its data: downloaded models and the SwiftData store, all
/// under `~/Library/Application Support/Dictum` (model weights in `Models`).
/// Application Support isn't TCC-gated, unlike `~/Documents`.
public enum ModelStorage {
    /// The app's own data directory: `~/Library/Application Support/Dictum`.
    public static var appSupportDirectory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("Dictum", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Root directory for all downloaded models: `~/Library/Application Support/Dictum/Models`.
    public static var modelsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Models", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// The SwiftData store for History/Dictionary/Snippets. It must be explicit: an
    /// unsandboxed app that takes SwiftData's default opens the shared
    /// `~/Library/Application Support/default.store`, and migrating it to this
    /// schema drops the tables of any other app using that same default.
    public static var swiftDataStoreURL: URL {
        appSupportDirectory.appendingPathComponent("Dictum.store")
    }

    /// Subdirectory for FluidAudio / Parakeet downloads.
    public static var parakeetDirectory: URL {
        let dir = modelsDirectory.appendingPathComponent("parakeet", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
