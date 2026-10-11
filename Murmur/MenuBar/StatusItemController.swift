import AppKit
import KeyboardShortcuts

/// Manages Dictum's menu-bar presence. The icon reflects dictation state; the
/// menu offers dictation toggle, settings, permission setup, and quit.
@MainActor
final class StatusItemController {
    private let appState: AppState
    private let onShowOnboarding: () -> Void
    private let onOpenScratchpad: () -> Void
    private let onOpenSettings: () -> Void
    private let statusItem: NSStatusItem

    init(
        appState: AppState,
        onShowOnboarding: @escaping () -> Void,
        onOpenScratchpad: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.onShowOnboarding = onShowOnboarding
        self.onOpenScratchpad = onOpenScratchpad
        self.onOpenSettings = onOpenSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        statusItem.menu = makeMenu()
        observeState()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = Self.symbol(for: appState.dictation?.state ?? .idle)
        button.toolTip = "Dictum"
    }

    private func observeState() {
        withObservationTracking {
            _ = appState.dictation?.state
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateIcon()
                self?.observeState()
            }
        }
    }

    private func updateIcon() {
        statusItem.button?.image = Self.symbol(for: appState.dictation?.state ?? .idle)
    }

    private static func symbol(for state: DictationController.State) -> NSImage? {
        let name: String
        switch state {
        case .recording: name = "mic.fill"
        case .transcribing, .polishing, .downloading: name = "waveform.circle"
        case .inserting: name = "checkmark.circle"
        case .error: name = "exclamationmark.triangle"
        case .idle, .listening: name = "waveform"
        }
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Dictum")
        image?.isTemplate = true
        return image
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let dictate = NSMenuItem(title: "Start / Stop Dictation", action: #selector(toggleDictation), keyEquivalent: "")
        dictate.target = self
        dictate.setShortcut(for: .toggleDictation)
        menu.addItem(dictate)

        let pasteLast = NSMenuItem(title: "Paste Last Result", action: #selector(pasteLastResult), keyEquivalent: "")
        pasteLast.target = self
        pasteLast.setShortcut(for: .pasteLast)
        menu.addItem(pasteLast)

        let scratchpad = NSMenuItem(title: "Open Scratchpad", action: #selector(openScratchpad), keyEquivalent: "")
        scratchpad.target = self
        menu.addItem(scratchpad)

        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let permissions = NSMenuItem(title: "Set Up Permissions…", action: #selector(showOnboarding), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Dictum", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    @objc private func toggleDictation() {
        appState.dictation?.toggle()
    }

    @objc private func pasteLastResult() {
        // Let the menu close and focus return to the app first.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            appState.dictation?.pasteLast()
        }
    }

    @objc private func openScratchpad() {
        onOpenScratchpad()
    }

    @objc private func openSettings() {
        onOpenSettings()
    }

    @objc private func showOnboarding() {
        onShowOnboarding()
    }
}
