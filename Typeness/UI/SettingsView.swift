import SwiftUI

// Placeholder — populated in Task 2
struct SettingsView: View {
    let appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        Text("Settings")
            .frame(width: 450, height: 300)
    }
}
