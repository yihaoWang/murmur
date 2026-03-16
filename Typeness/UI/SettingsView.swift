import SwiftUI
import ServiceManagement

struct SettingsView: View {
    let appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState, settingsStore: settingsStore)
                .tabItem { Label("General", systemImage: "gear") }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    let appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    private var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("SMAppService error: \(error)")
                        }
                    }
                ))
            }

            Section("Hotkeys") {
                LabeledContent("Toggle Mode") {
                    Text("⇧⌥Space")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Push to Talk") {
                    Text("⌥Space")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Permissions") {
                LabeledContent("Accessibility") {
                    Text(appState.accessibilityStatus == .granted ? "Granted" : "Not Granted")
                        .foregroundStyle(appState.accessibilityStatus == .granted ? .green : .red)
                }
                LabeledContent("Microphone") {
                    Text(appState.microphoneStatus == .granted ? "Granted" : "Not Granted")
                        .foregroundStyle(appState.microphoneStatus == .granted ? .green : .red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
