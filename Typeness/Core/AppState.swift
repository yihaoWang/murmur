import Foundation
import Observation

@Observable final class AppState {
    var hotkeyStatus: HotkeyStatus = .unregistered
    var accessibilityStatus: PermissionStatus = .unknown
    var microphoneStatus: PermissionStatus = .unknown
    var modelDownloadProgress: Double? = nil
    var isFirstLaunch: Bool {
        !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
    }

    enum HotkeyStatus { case unregistered, active, disabled }
    enum PermissionStatus { case unknown, granted, denied, revoked }
}
