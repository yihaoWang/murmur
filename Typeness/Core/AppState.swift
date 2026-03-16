import Foundation
import Observation
import ApplicationServices

@Observable final class AppState {
    var hotkeyStatus: HotkeyStatus = .unregistered
    var accessibilityStatus: PermissionStatus = .unknown
    var microphoneStatus: PermissionStatus = .unknown
    var modelDownloadProgress: Double? = nil
    var isWhisperModelReady: Bool = false
    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }

    enum HotkeyStatus { case unregistered, active, disabled }
    enum PermissionStatus { case unknown, granted, denied, revoked }
    enum RecordingState { case idle, recording, transcribing }

    var recordingState: RecordingState = .idle

    func checkAccessibilityOnStartup() {
        if AXIsProcessTrusted() {
            accessibilityStatus = .granted
        } else {
            accessibilityStatus = .revoked
        }
    }
}
