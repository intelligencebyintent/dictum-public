#if DEBUG
import AppKit
import ApplicationServices
import Foundation
import KeyboardShortcuts
import MurmurKit

/// DEBUG-only: the in-app half of the Network Guard test (`scripts/network-guard.sh`).
///
/// Launched as `Dictum -selfTestWAV <file> [-selfTestLLM <baseURL> -selfTestModel <id>]`
/// or `[-selfTestLLM apple]`, the fully started app runs one dictation from the
/// file through the real pipeline (Parakeet, then cleanup via the given local
/// server or Apple's on-device model, then dictionary replacements), prints one
/// JSON line to stdout, and exits. It uses a throwaway
/// settings domain so the user's real settings are untouched, and it never pastes.
@MainActor
enum SelfTest {
    struct Request {
        let wav: URL
        let llmBaseURL: String?
        let llmModel: String?

        static func fromArguments(_ args: [String] = ProcessInfo.processInfo.arguments) -> Request? {
            func value(after flag: String) -> String? {
                guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
                return args[i + 1]
            }
            guard let wav = value(after: "-selfTestWAV") else { return nil }
            return Request(
                wav: URL(fileURLWithPath: wav),
                llmBaseURL: value(after: "-selfTestLLM"),
                llmModel: value(after: "-selfTestModel")
            )
        }
    }

    /// Run the request, print the result, and exit the process.
    static func run(_ request: Request) {
        Task { @MainActor in
            exit(await execute(request))
        }
    }

    private static func execute(_ request: Request) async -> Int32 {
        let suite = "dictum.selftest.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            return report(["ok": false, "error": "couldn't create a throwaway settings domain"])
        }
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = AppSettings(defaults: defaults)
        settings.polishEnabled = request.llmBaseURL != nil
        if request.llmBaseURL == "apple" {
            settings.llmProviderID = .appleOnDevice
        } else if let baseURL = request.llmBaseURL {
            settings.llmProviderID = .lmStudio
            settings.lmStudioBaseURL = baseURL
            settings.setSelectedLLMModelID(request.llmModel ?? "selftest", for: .lmStudio)
        }
        let controller = DictationController(
            settings: settings,
            registry: EngineRegistry(settings: settings),
            insertion: TextInsertionService(),
            accessibility: AccessibilityReader()
        )

        let start = Date()
        do {
            let samples = try AudioFileLoader.loadMono16k(request.wav)
            guard let (raw, final) = try await controller.process(samples: samples) else {
                return report(["ok": false, "error": "empty transcript"])
            }
            // Synthetic test audio only, so printing the text here is fine.
            return report([
                "ok": true,
                "raw": raw,
                "final": final,
                "ms": Int(Date().timeIntervalSince(start) * 1000),
            ])
        } catch {
            return report(["ok": false, "error": String(describing: error)])
        }
    }

    // MARK: - Cancel key

    /// `Dictum -selfTestCancelKey`: claim the cancel shortcut the way a
    /// dictation does, send one Esc, and check that it reached the handler and
    /// that Esc is released again afterward.
    static var wantsCancelKeyTest: Bool {
        ProcessInfo.processInfo.arguments.contains("-selfTestCancelKey")
    }

    static func runCancelKeyTest() {
        Task { @MainActor in
            final class Flag { var fired = false }
            let flag = Flag()
            let hotkeys = HotkeyManager()
            hotkeys.onCancel = { flag.fired = true }
            hotkeys.cancelArmed = true
            let claimed = KeyboardShortcuts.isEnabled(for: .cancelDictation)

            let source = CGEventSource(stateID: .hidSystemState)
            CGEvent(keyboardEventSource: source, virtualKey: 0x35, keyDown: true)?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: 0x35, keyDown: false)?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(400))

            hotkeys.cancelArmed = false
            let released = !KeyboardShortcuts.isEnabled(for: .cancelDictation)
            exit(report([
                "ok": claimed && flag.fired && released,
                "claimed": claimed,
                "fired": flag.fired,
                "released": released,
                "shortcut": KeyboardShortcuts.getShortcut(for: .cancelDictation).map(String.init(describing:)) ?? "none",
            ]))
        }
    }

    // MARK: - Insertion

    /// `Dictum -selfTestInsert <text> -selfTestExpectWindow <title part>
    /// [-selfTestDelay <seconds>]`: after the delay, insert `text` into the
    /// focused field through the real insertion path, then report how it went
    /// in, whether the field now holds it, and whether a multi-item, multi-type
    /// clipboard came back exactly. The user's real clipboard is saved first and
    /// put back at the end. Refuses to type unless the focused window's title
    /// contains the expected part, so it can't land in one of the user's documents.
    struct InsertRequest {
        let text: String
        let expectedWindow: String
        let delay: Double
        /// `-selfTestSkipPaste`: don't send ⌘V, to exercise the Accessibility fallback.
        let skipPaste: Bool

        static func fromArguments(_ args: [String] = ProcessInfo.processInfo.arguments) -> InsertRequest? {
            func value(after flag: String) -> String? {
                guard let i = args.firstIndex(of: flag), args.indices.contains(i + 1) else { return nil }
                return args[i + 1]
            }
            guard let text = value(after: "-selfTestInsert") else { return nil }
            return InsertRequest(
                text: text,
                expectedWindow: value(after: "-selfTestExpectWindow") ?? "",
                delay: value(after: "-selfTestDelay").flatMap(Double.init) ?? 0,
                skipPaste: args.contains("-selfTestSkipPaste")
            )
        }
    }

    static func run(_ request: InsertRequest) {
        Task { @MainActor in
            exit(await execute(request))
        }
    }

    private static func execute(_ request: InsertRequest) async -> Int32 {
        try? await Task.sleep(for: .seconds(request.delay))
        let window = focusedWindowTitle() ?? ""
        guard !request.expectedWindow.isEmpty, window.contains(request.expectedWindow) else {
            return report(["ok": false, "error": "focused window isn't the test target; typed nothing", "window": window])
        }
        let pasteboard = NSPasteboard.general
        let saved = ClipboardCopy(pasteboard)
        defer { saved.write(to: pasteboard) }

        // A clipboard with two items and several types, one of them private.
        let rtf = Data(#"{\rtf1\ansi Dictum {\b clipboard} probe}"#.utf8)
        let custom = NSPasteboard.PasteboardType("com.intelligencebyintent.dictum.selftest")
        let first = NSPasteboardItem()
        first.setString("Dictum clipboard probe", forType: .string)
        first.setData(rtf, forType: .rtf)
        first.setData(Data([0, 1, 2, 3]), forType: custom)
        let second = NSPasteboardItem()
        second.setString("Second item", forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])
        let probe = ClipboardCopy(pasteboard)

        let insertion = TextInsertionService()
        insertion.skipsPasteForTesting = request.skipPaste
        guard insertion.isTrusted else {
            return report(["ok": false, "error": "Dictum isn't trusted for Accessibility"])
        }
        let app = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown"
        let focused = FocusedElement.current()
        let start = Date()
        let outcome = await insertion.insert(request.text)
        let ms = Int(Date().timeIntervalSince(start) * 1000)

        // Let a slow app finish drawing before reading the field back.
        try? await Task.sleep(for: .milliseconds(300))
        var value: CFTypeRef?
        var landed: Any = NSNull()   // unknown when the field doesn't expose its text
        if let focused,
           AXUIElementCopyAttributeValue(focused.element, kAXValueAttribute as CFString, &value) == .success,
           let text = value as? String {
            landed = text.contains(request.text)
        }
        let restored = ClipboardCopy(pasteboard) == probe

        let ok: Bool = switch outcome {
        case .pasted, .accessibility: restored && (landed as? Bool ?? true)
        case .refusedSecureField: restored && (landed as? Bool ?? false) == false
        case .copiedToClipboard: false
        }
        // Synthetic test text only, so printing it is fine.
        return report([
            "ok": ok,
            "app": app,
            "outcome": String(describing: outcome),
            "landed": landed,
            "clipboardRestored": restored,
            "ms": ms,
        ])
    }

    /// The title of the frontmost app's focused window.
    private static func focusedWindowTitle() -> String? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        let app = AXUIElementCreateApplication(pid)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID() else { return nil }
        var title: CFTypeRef?
        // Safe: the type was just verified above.
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success else { return nil }
        return title as? String
    }

    /// Every item and type on a pasteboard, comparable.
    private struct ClipboardCopy: Equatable {
        let items: [[String: Data]]

        init(_ pasteboard: NSPasteboard) {
            items = (pasteboard.pasteboardItems ?? []).map { item in
                var types: [String: Data] = [:]
                for type in item.types {
                    if let data = item.data(forType: type) { types[type.rawValue] = data }
                }
                return types
            }
        }

        func write(to pasteboard: NSPasteboard) {
            pasteboard.clearContents()
            guard !items.isEmpty else { return }
            pasteboard.writeObjects(items.map { types in
                let item = NSPasteboardItem()
                for (type, data) in types { item.setData(data, forType: NSPasteboard.PasteboardType(type)) }
                return item
            })
        }
    }

    private static func report(_ fields: [String: Any]) -> Int32 {
        if let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]) {
            FileHandle.standardOutput.write(data + Data("\n".utf8))
        }
        return (fields["ok"] as? Bool ?? false) ? 0 : 1
    }
}
#endif
