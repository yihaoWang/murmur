import SwiftUI

@main
struct TypenessApp: App {
    @State private var appState = AppState()
    @StateObject private var settingsStore = SettingsStore()
    @State private var modelManager: ModelManager?
    @State private var hotkeyMonitor = HotkeyMonitor()
    @State private var showOnboarding = false
    @State private var audioEngine = AudioCaptureEngine()
    @State private var transcriptionEngine = TranscriptionEngine()

    var body: some Scene {
        // Hidden window — MUST be first scene for openSettings() to work in LSUIElement app
        Window("hidden", id: "hidden") {
            Color.clear
                .frame(width: 0, height: 0)
                .task {
                    let manager = ModelManager(appState: appState)
                    modelManager = manager
                    await manager.checkAndUpdateModelStatus()
                    if await manager.isWhisperModelDownloaded() {
                        await transcriptionEngine.load(modelURL: await manager.whisperModelPath())
                    }
                    Task {
                        try? await manager.downloadWhisperModelIfNeeded()
                        await transcriptionEngine.load(modelURL: await manager.whisperModelPath())
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

        setupHotkeyObservers()
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

    private func setupHotkeyObservers() {
        NotificationCenter.default.addObserver(
            forName: .hotkeyToggleFired, object: nil, queue: .main
        ) { _ in
            Task { await handleToggle() }
        }
        NotificationCenter.default.addObserver(
            forName: .hotkeyPTTDown, object: nil, queue: .main
        ) { _ in
            Task { await handleRecordingStart() }
        }
        NotificationCenter.default.addObserver(
            forName: .hotkeyPTTUp, object: nil, queue: .main
        ) { _ in
            Task { await handleRecordingStop() }
        }
    }

    private func handleToggle() async {
        if appState.recordingState == .idle {
            await handleRecordingStart()
        } else if appState.recordingState == .recording {
            await handleRecordingStop()
        }
    }

    private func handleRecordingStart() async {
        guard await audioEngine.checkMicrophonePermission() else {
            appState.microphoneStatus = .denied
            return
        }
        appState.microphoneStatus = .granted
        do {
            try await audioEngine.start()
            appState.recordingState = .recording
        } catch {
            print("[Typeness] Audio engine start failed: \(error)")
            appState.recordingState = .idle
        }
    }

    private func handleRecordingStop() async {
        guard appState.recordingState == .recording else { return }
        let frames = await audioEngine.stop()
        appState.recordingState = .transcribing

        guard VADGate.hasVoiceActivity(samples: frames) else {
            print("[Typeness] No voice activity detected, skipping transcription")
            appState.recordingState = .idle
            return
        }

        do {
            let text = try await transcriptionEngine.transcribe(audioFrames: frames)
            appState.lastTranscription = text
            print("[Typeness] Transcription: \(text)")
            // Phase 3 will insert text at cursor; Phase 2 just logs
        } catch {
            print("[Typeness] Transcription failed: \(error)")
        }
        appState.recordingState = .idle
    }
}
