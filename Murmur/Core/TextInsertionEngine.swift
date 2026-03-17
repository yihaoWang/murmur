import Foundation
import AppKit
import ApplicationServices
import CoreGraphics
import UserNotifications

/// Enum describing which path was used to insert text.
enum InsertionPath {
    case accessibility
    case clipboardPaste
    case clipboardOnly
}

/// Inserts formatted text at the cursor in any macOS application.
///
/// Primary path: AXUIElement `kAXSelectedTextAttribute` — directly sets text at cursor
/// without touching the clipboard.
///
/// Fallback path: Clipboard paste — writes text to NSPasteboard and synthesizes Cmd+V.
///
/// Last resort: Clipboard only — text is left in clipboard for manual Cmd+V.
struct TextInsertionEngine {

    // MARK: - Public API

    /// Insert `text` at the current cursor position.
    ///
    /// - Returns: The `InsertionPath` that was actually used.
    @discardableResult
    func insert(_ text: String) -> InsertionPath {
        let hasAccessibility = AXIsProcessTrusted()

        if hasAccessibility && tryAccessibilityInsert(text) {
            AppLogger.log("text inserted via accessibility API")
            return .accessibility
        }

        // Write text to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        if hasAccessibility {
            // Can simulate Cmd+V
            let snapshot = snapshotPasteboard(pasteboard)
            simulatePaste()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.restorePasteboard(pasteboard, from: snapshot)
            }
            AppLogger.log("text inserted via clipboard paste")
            return .clipboardPaste
        } else {
            // No accessibility — leave text in clipboard, don't restore.
            // User can Cmd+V manually.
            AppLogger.log("text copied to clipboard (no accessibility — use Cmd+V to paste)")
            showNotification(text: text)
            return .clipboardOnly
        }
    }

    // MARK: - AX Primary Path

    private func tryAccessibilityInsert(_ text: String) -> Bool {
        var focusedElement: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        let err = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        guard err == .success, let element = focusedElement else {
            return false
        }
        let result = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }

    // MARK: - Clipboard Paste

    private func simulatePaste() {
        // Synthesize Cmd+V (virtual key 9 = 'v').
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Notification

    private func showNotification(text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Murmur"
        content.body = "已複製到剪貼簿：\(text.prefix(100))"
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Clipboard Snapshot / Restore

    func snapshotPasteboard(_ pb: NSPasteboard) -> [(NSPasteboard.PasteboardType, Data)] {
        var result: [(NSPasteboard.PasteboardType, Data)] = []
        for item in pb.pasteboardItems ?? [] {
            for type in item.types {
                if let data = item.data(forType: type) {
                    result.append((type, data))
                }
            }
        }
        return result
    }

    func restorePasteboard(_ pb: NSPasteboard, from snapshot: [(NSPasteboard.PasteboardType, Data)]) {
        pb.clearContents()
        if snapshot.isEmpty { return }
        let item = NSPasteboardItem()
        for (type, data) in snapshot {
            item.setData(data, forType: type)
        }
        pb.writeObjects([item])
    }
}
