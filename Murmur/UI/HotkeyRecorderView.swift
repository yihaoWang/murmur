import SwiftUI
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleMode = Self("toggleMode", default: .init(.space, modifiers: [.option, .shift]))
    static let pushToTalk = Self("pushToTalk", default: .init(.space, modifiers: [.option]))
}

struct HotkeyRecorderRow: View {
    let title: String
    let name: KeyboardShortcuts.Name
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        LabeledContent(title) {
            KeyboardShortcuts.Recorder(for: name) { shortcut in
                syncToSettingsStore(shortcut: shortcut)
            }
        }
    }

    private func syncToSettingsStore(shortcut: KeyboardShortcuts.Shortcut?) {
        guard let shortcut = shortcut,
              let key = shortcut.key else { return }

        let keyCode = Int(key.rawValue)

        // Convert NSEvent.ModifierFlags to CGEventFlags raw Int
        var modifiersRaw: Int = 0
        let nsModifiers = shortcut.modifiers
        if nsModifiers.contains(.option)  { modifiersRaw |= 524288  }  // maskAlternate
        if nsModifiers.contains(.shift)   { modifiersRaw |= 131072  }  // maskShift
        if nsModifiers.contains(.command) { modifiersRaw |= 1048576 }  // maskCommand
        if nsModifiers.contains(.control) { modifiersRaw |= 262144  }  // maskControl

        if name == .toggleMode {
            settingsStore.toggleHotkeyKeyCode = keyCode
            settingsStore.toggleHotkeyModifiers = modifiersRaw
        } else if name == .pushToTalk {
            settingsStore.pttHotkeyKeyCode = keyCode
            settingsStore.pttHotkeyModifiers = modifiersRaw
        }
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
}
