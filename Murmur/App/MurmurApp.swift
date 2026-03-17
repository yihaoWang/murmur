import SwiftUI
import KeyboardShortcuts

@main
struct MurmurApp: App {
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
        MenuBarExtra {
            StatusItemView(appState: appState, modelManager: modelManager)
                .task {
                    setupApp()
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
                        do {
                            AppLogger.log("loading LLM post-processing...")
                            try await postProcessingEngine.load { progress in
                                appState.llmDownloadProgress = progress
                            }
                            appState.isLLMModelReady = true
                            AppLogger.log("LLM post-processing ready")
                        } catch {
                            AppLogger.log("LLM post-processing unavailable: \(error)")
                        }
                        appState.llmDownloadProgress = nil
                    }
                }
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
        AppLogger.log("setupApp started")
        appState.checkAccessibilityOnStartup()
        AppLogger.log("accessibility=\(appState.accessibilityStatus)")

        // Disable KeyboardShortcuts framework interception — we use CGEventTap instead
        KeyboardShortcuts.disable(.toggleMode)
        KeyboardShortcuts.disable(.pushToTalk)

        if appState.accessibilityStatus == .granted {
            startHotkeyMonitor()
        } else {
            AppLogger.log("accessibility not granted — hotkeys disabled, using clipboard-only insertion")
            // Poll in background so hotkeys activate if user grants permission later
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    appState.accessibilityStatus = .granted
                    startHotkeyMonitor()
                    AppLogger.log("accessibility granted, hotkey monitor started")
                }
            }
        }

        setupHotkeyObservers()
        AppLogger.log("setupApp done")
    }

    private func startHotkeyMonitor() {
        hotkeyMonitor.loadSettings(from: settingsStore)
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
        AppLogger.log("handleRecordingStart")
        guard appState.recordingState == .idle else {
            AppLogger.log("not idle, ignoring start")
            return
        }
        // Set state synchronously before any await to prevent re-entry
        appState.recordingState = .recording
        guard await audioEngine.checkMicrophonePermission() else {
            AppLogger.log("microphone permission denied")
            appState.microphoneStatus = .denied
            appState.recordingState = .idle
            return
        }
        appState.microphoneStatus = .granted
        do {
            try await audioEngine.start()
            appState.recordingState = .recording
            RecordingOverlayWindow.shared.show(state: .recording)
            AppLogger.log("recording started")
        } catch {
            AppLogger.log("audio engine start failed: \(error)")
            appState.recordingState = .idle
        }
    }

    private func handleRecordingStop() async {
        AppLogger.log("handleRecordingStop")
        guard appState.recordingState == .recording else {
            AppLogger.log("not recording, ignoring stop")
            return
        }
        // Set state synchronously before any await to prevent re-entry
        appState.recordingState = .transcribing
        let frames = await audioEngine.stop()
        let startTime = Date()
        RecordingOverlayWindow.shared.show(state: .transcribing)
        AppLogger.log("audio stopped, frames=\(frames.count)")

        guard VADGate.hasVoiceActivity(samples: frames) else {
            AppLogger.log("no voice activity, skipping")
            RecordingOverlayWindow.shared.hide()
            appState.recordingState = .idle
            return
        }

        do {
            AppLogger.log("transcribing...")
            let rawText = try await transcriptionEngine.transcribe(audioFrames: frames)
            let latencyMs = Date().timeIntervalSince(startTime) * 1000
            appState.lastTranscriptionLatencyMs = latencyMs
            AppLogger.log("transcribed in \(Int(latencyMs))ms: \(rawText.prefix(80))")

            appState.recordingState = .processing
            let finalText: String
            if await postProcessingEngine.isLoaded {
                AppLogger.log("post-processing...")
                finalText = try await postProcessingEngine.format(rawText)
            } else {
                finalText = rawText
            }

            if settingsStore.confirmBeforeInsert {
                appState.pendingTranscription = finalText
                appState.lastTranscription = rawText
                if settingsStore.debugModeEnabled {
                    appState.pendingDebugContext = AppState.PendingDebugContext(
                        frames: frames,
                        rawTranscription: rawText,
                        formattedText: finalText,
                        latencyMs: latencyMs
                    )
                }
                AppLogger.log("pending confirmation")
            } else {
                AppLogger.log("inserting text...")
                let path = textInsertionEngine.insert(finalText)
                AppLogger.log("inserted via \(path)")
                RecordingOverlayWindow.shared.show(state: .done)
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
            AppLogger.log("recording pipeline done")
        } catch {
            AppLogger.log("pipeline error: \(error)")
            RecordingOverlayWindow.shared.hide()
            appState.lastError = error.localizedDescription
            appState.recordingState = .idle
        }
    }
}
