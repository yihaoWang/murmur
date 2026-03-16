import CoreGraphics
import ApplicationServices
import Foundation

extension Notification.Name {
    static let hotkeyToggleFired = Notification.Name("hotkeyToggleFired")
    static let hotkeyPTTDown = Notification.Name("hotkeyPTTDown")
    static let hotkeyPTTUp = Notification.Name("hotkeyPTTUp")
}

enum HotkeyError: Error {
    case accessibilityNotGranted
    case tapCreationFailed
}

final class HotkeyMonitor {
    var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Hotkey config — read from SettingsStore at init
    var toggleKeyCode: Int64 = 49       // Space
    var toggleModifiers: CGEventFlags = [.maskAlternate, .maskShift]  // Shift+Option
    var pttKeyCode: Int64 = 49          // Space
    var pttModifiers: CGEventFlags = [.maskAlternate]  // Option only

    func start() throws {
        guard AXIsProcessTrusted() else {
            throw HotkeyError.accessibilityNotGranted
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotkeyCallback,
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else {
            throw HotkeyError.tapCreationFailed
        }
        self.tap = tap

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    func matchesToggle(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == toggleKeyCode &&
        flags.contains(toggleModifiers) &&
        !flags.contains(.maskCommand) &&
        !flags.contains(.maskControl)
    }

    func matchesPTT(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == pttKeyCode &&
        flags.contains(pttModifiers) &&
        !flags.contains(.maskShift) &&
        !flags.contains(.maskCommand) &&
        !flags.contains(.maskControl)
    }
}

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

    // CRITICAL: handle timeout re-enable FIRST
    if type == .tapDisabledByTimeout {
        if let tap = monitor.tap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if type == .keyDown {
        if monitor.matchesToggle(keyCode: keyCode, flags: flags) {
            NotificationCenter.default.post(name: .hotkeyToggleFired, object: nil)
            return nil  // Suppress
        }
        if monitor.matchesPTT(keyCode: keyCode, flags: flags) {
            NotificationCenter.default.post(name: .hotkeyPTTDown, object: nil)
            return nil  // Suppress
        }
    } else if type == .keyUp {
        if monitor.matchesPTT(keyCode: keyCode, flags: flags) {
            NotificationCenter.default.post(name: .hotkeyPTTUp, object: nil)
            return nil  // Suppress
        }
    }

    return Unmanaged.passRetained(event)
}
