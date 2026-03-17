import Foundation
import SwiftUI

final class SettingsStore: ObservableObject {
    @AppStorage("toggleHotkeyKeyCode") var toggleHotkeyKeyCode: Int = 49
    @AppStorage("toggleHotkeyModifiers") var toggleHotkeyModifiers: Int = 655360
    @AppStorage("pttHotkeyKeyCode") var pttHotkeyKeyCode: Int = 49
    @AppStorage("pttHotkeyModifiers") var pttHotkeyModifiers: Int = 524288
    @AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false
    @AppStorage("confirmBeforeInsert") var confirmBeforeInsert: Bool = false
    @AppStorage("hasShownOnboarding") var hasShownOnboarding: Bool = false
    @AppStorage("selectedWhisperModel") var selectedWhisperModel: String = WhisperModel.medium.rawValue
}
