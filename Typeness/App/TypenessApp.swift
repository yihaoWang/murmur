import SwiftUI

@main
struct TypenessApp: App {
    @State private var appState = AppState()
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        // Hidden window — MUST be first scene for openSettings() to work in LSUIElement app
        Window("hidden", id: "hidden") {
            Color.clear
                .frame(width: 0, height: 0)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)

        MenuBarExtra("Typeness", systemImage: "mic.fill") {
            StatusItemView(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState, settingsStore: settingsStore)
        }
    }
}
