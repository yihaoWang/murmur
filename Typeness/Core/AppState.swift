import Foundation
import Observation
import ApplicationServices

@Observable final class AppState {
    var hotkeyStatus: HotkeyStatus = .unregistered
    var accessibilityStatus: PermissionStatus = .unknown
    var microphoneStatus: PermissionStatus = .unknown
    var modelDownloadProgress: Double? = nil
    var isWhisperModelReady: Bool = false
    var isLLMModelReady: Bool = false
    var llmDownloadProgress: Double? = nil
    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }

    enum HotkeyStatus { case unregistered, active, disabled }
    enum PermissionStatus { case unknown, granted, denied, revoked }
    enum RecordingState { case idle, recording, transcribing, processing }

    var recordingState: RecordingState = .idle
    var lastTranscription: String = ""
    var lastTranscriptionLatencyMs: Double? = nil
    var pendingTranscription: String? = nil
    var pendingDebugContext: PendingDebugContext? = nil
    var lastError: String? = nil

    struct PendingDebugContext {
        let frames: [Float]
        let rawTranscription: String
        let formattedText: String
        let latencyMs: Double
    }

    var menuBarIconName: String {
        if lastError != nil { return "exclamationmark.triangle" }
        switch recordingState {
        case .idle:         return "mic"
        case .recording:    return "mic.fill"
        case .transcribing: return "waveform"
        case .processing:   return "ellipsis.circle"
        }
    }

    func checkAccessibilityOnStartup() {
        if AXIsProcessTrusted() {
            accessibilityStatus = .granted
        } else {
            accessibilityStatus = .revoked
        }
    }
}
