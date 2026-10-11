import os

/// Centralized `os.Logger` categories. Use these instead of `print` so output is
/// structured, filterable in Console.app, and stripped from release as needed.
public enum Log {
    public static let subsystem = "com.intelligencebyintent.dictum"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let audio = Logger(subsystem: subsystem, category: "audio")
    public static let engine = Logger(subsystem: subsystem, category: "engine")
    public static let llm = Logger(subsystem: subsystem, category: "llm")
    public static let hotkey = Logger(subsystem: subsystem, category: "hotkey")
    public static let insertion = Logger(subsystem: subsystem, category: "insertion")
    public static let pipeline = Logger(subsystem: subsystem, category: "pipeline")
    public static let permissions = Logger(subsystem: subsystem, category: "permissions")
    public static let settings = Logger(subsystem: subsystem, category: "settings")
}
