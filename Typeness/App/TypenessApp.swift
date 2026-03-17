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
    @State private var postProcessingEngine = PostProcessingEngine()
    private let textInsertionEngine = TextInsertionEngine()

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
                    Task {
                        try? await postProcessingEngine.load { progress in
                            appState.llmDownloadProgress = progress
                        }
                        appState.isLLMModelReady = true
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

        MenuBarExtra {
            StatusItemView(appState: appState, modelManager: modelManager)
        } label: {
            Image(systemName: appState.menuBarIconName)
                .symbolRenderingMode(.hierarchical)
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
        let startTime = Date()
        appState.recordingState = .transcribing

        guard VADGate.hasVoiceActivity(samples: frames) else {
            print("[Typeness] No voice activity detected, skipping transcription")
            appState.recordingState = .idle
            return
        }

        do {
            let rawText = try await transcriptionEngine.transcribe(audioFrames: frames)
            let latencyMs = Date().timeIntervalSince(startTime) * 1000
            appState.lastTranscriptionLatencyMs = latencyMs

            appState.recordingState = .processing
            let finalText: String
            if await postProcessingEngine.isLoaded {
                finalText = try await postProcessingEngine.format(rawText)
            } else {
                finalText = rawText
            }

            if settingsStore.confirmBeforeInsert {
                appState.pendingTranscription = finalText
                appState.lastTranscription = rawText
                // insertion deferred to ConfirmInsertView callback
            } else {
                let path = textInsertionEngine.insert(finalText)
                appState.lastTranscription = rawText
                if settingsStore.debugModeEnabled {
                    try? DebugArchiver.save(
                        frames: frames,
                        transcription: rawText,
                        formattedText: finalText,
                        latencyMs: latencyMs,
                        insertionPath: path == .accessibility ? "accessibility" : "clipboardPaste"
                    )
                }
                appState.recordingState = .idle
            }
        } catch {
            appState.lastError = error.localizedDescription
            appState.recordingState = .idle
        }
    }
}
