import SwiftUI

@main
struct TypenessApp: App {
    @State private var appState = AppState()
    @StateObject private var settingsStore = SettingsStore()
    @State private var modelManager: ModelManager?
    @State private var hotkeyMonitor = HotkeyMonitor()
    @State private var showOnboarding = false

    var body: some Scene {
        // Hidden window — MUST be first scene for openSettings() to work in LSUIElement app
        Window("hidden", id: "hidden") {
            Color.clear
                .frame(width: 0, height: 0)
                .task {
                    let manager = ModelManager(appState: appState)
                    modelManager = manager
                    await manager.checkAndUpdateModelStatus()
                    Task {
                        try? await manager.downloadWhisperModelIfNeeded()
                    }
                }
                .onAppear {
                    setupApp()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(appState: appState) {
                        showOnboarding = false
                        settingsStore.hasShownOnboarding = true
                        startHotkeyMonitor()
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)

        MenuBarExtra("Typeness", systemImage: "mic.fill") {
            StatusItemView(appState: appState, modelManager: modelManager)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState, settingsStore: settingsStore)
        }
    }

    private func setupApp() {
        appState.checkAccessibilityOnStartup()

        if !settingsStore.hasShownOnboarding {
            showOnboarding = true
        } else if appState.accessibilityStatus == .granted {
            startHotkeyMonitor()
        }
    }

    private func startHotkeyMonitor() {
        hotkeyMonitor.toggleKeyCode = Int64(settingsStore.toggleHotkeyKeyCode)
        hotkeyMonitor.pttKeyCode = Int64(settingsStore.pttHotkeyKeyCode)
        do {
            try hotkeyMonitor.start()
            appState.hotkeyStatus = .active
        } catch {
            appState.hotkeyStatus = .disabled
        }
    }
}
