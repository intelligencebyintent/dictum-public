import SwiftUI

/// The Settings window: a sidebar of panes + detail, mirroring Wispr Flow's
/// settings surface. Monochrome, native Form-based panes.
enum SettingsPane: String, CaseIterable, Identifiable, Hashable {
    case general, shortcuts, transcription, polish, transforms, dictionary, snippets, audio, history, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .shortcuts: "Shortcuts"
        case .transcription: "Transcription"
        case .polish: "AI Polish"
        case .transforms: "Transforms"
        case .dictionary: "Dictionary"
        case .snippets: "Snippets"
        case .audio: "Audio"
        case .history: "History"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape"
        case .shortcuts: "command"
        case .transcription: "waveform"
        case .polish: "sparkles"
        case .transforms: "wand.and.stars"
        case .dictionary: "character.book.closed"
        case .snippets: "text.badge.plus"
        case .audio: "mic"
        case .history: "clock"
        case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    @Environment(AppState.self) private var appState
    @State private var selection: SettingsPane? = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $selection) { pane in
                Label(pane.title, systemImage: pane.icon).tag(pane)
            }
            .navigationSplitViewColumnWidth(196)
        } detail: {
            detail
                .frame(minWidth: 480, minHeight: 440)
        }
        .frame(width: 760, height: 520)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .general {
        case .general: GeneralPane()
        case .shortcuts: ShortcutsPane()
        case .transcription: TranscriptionPane()
        case .polish: PolishPane()
        case .transforms: TransformsPane()
        case .dictionary: DictionaryPane()
        case .snippets: SnippetsPane()
        case .audio: AudioPane()
        case .history: HistoryPane()
        case .about: AboutPane()
        }
    }
}
