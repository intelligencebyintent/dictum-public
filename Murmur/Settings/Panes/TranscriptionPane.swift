import SwiftUI
import MurmurKit

struct TranscriptionPane: View {
    @Environment(AppState.self) private var appState

    @State private var prepareState: PrepareState = .idle
    private enum PrepareState: Equatable {
        case idle, working(Double), ready, failed(String)
    }

    var body: some View {
        @Bindable var settings = appState.settings
        let engine = settings.transcriptionEngineID

        Form {
            Section("Engine") {
                Picker("Transcribe with", selection: $settings.transcriptionEngineID) {
                    ForEach(TranscriptionEngineID.allCases) { engine in
                        Text(engine.displayName).tag(engine)
                    }
                }

                Picker("Model", selection: modelBinding(for: engine)) {
                    ForEach(ModelCatalog.transcriptionModels(for: engine)) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
            }

            Section("On-device model") {
                let model = settings.selectedTranscriptionModel(for: engine)
                LabeledContent("Size") {
                    Text(model.approxSizeMB.map { "~\($0) MB" } ?? "—")
                        .foregroundStyle(.secondary)
                }
                prepareRow
                Text("Models download from Hugging Face once, on first use. After that, transcription runs entirely on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Transcription")
        .onChange(of: settings.transcriptionEngineID) { _, _ in
            appState.registry.resetPreparedEngine()
            prepareState = appState.registry.isCurrentEnginePrepared ? .ready : .idle
        }
        .onChange(of: settings.selectedTranscriptionModel(for: engine).id) { _, _ in
            appState.registry.resetPreparedEngine()
            prepareState = .idle
        }
        .onAppear {
            if appState.registry.isCurrentEnginePrepared { prepareState = .ready }
        }
    }

    @ViewBuilder
    private var prepareRow: some View {
        switch prepareState {
        case .idle:
            Button("Download & load model") { prepareModel() }
        case .working(let progress):
            HStack {
                ProgressView(value: progress)
                Text("\(Int(progress * 100))%").monospacedDigit().foregroundStyle(.secondary)
            }
        case .ready:
            Label("Ready", systemImage: "checkmark.circle").foregroundStyle(.secondary)
        case .failed(let message):
            VStack(alignment: .leading) {
                Label("Failed", systemImage: "exclamationmark.triangle").foregroundStyle(.secondary)
                Text(message).font(.caption).foregroundStyle(.secondary)
                Button("Retry") { prepareModel() }
            }
        }
    }

    private func modelBinding(for engine: TranscriptionEngineID) -> Binding<String> {
        Binding(
            get: { appState.settings.selectedTranscriptionModel(for: engine).id },
            set: { appState.settings.setSelectedTranscriptionModel($0, for: engine) }
        )
    }

    private func prepareModel() {
        prepareState = .working(0)
        Task {
            do {
                // Warm the SHARED registry engine so the dictation pipeline reuses
                // this exact prepared model (no redundant re-download/reload).
                _ = try await appState.registry.preparedTranscriptionEngine { progress in
                    Task { @MainActor in
                        if case .working = prepareState { prepareState = .working(progress) }
                    }
                }
                prepareState = .ready
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                prepareState = .failed(message)
            }
        }
    }
}
