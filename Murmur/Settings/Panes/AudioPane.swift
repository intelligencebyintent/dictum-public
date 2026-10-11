import SwiftUI
import MurmurKit

struct AudioPane: View {
    @Environment(AppState.self) private var appState
    @State private var devices: [AudioInputDevice] = []

    var body: some View {
        @Bindable var settings = appState.settings
        Form {
            Section("Microphone") {
                Picker("Input device", selection: Binding(
                    get: { settings.inputDeviceUID ?? "" },
                    set: { settings.inputDeviceUID = $0.isEmpty ? nil : $0 }
                )) {
                    Text("System Default").tag("")
                    ForEach(devices) { device in
                        Text(device.name).tag(device.uid)
                    }
                }
                Text("Dictum records at 16 kHz mono. Changing the device takes effect on the next dictation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Audio")
        .onAppear { devices = AudioDevices.inputDevices() }
    }
}
