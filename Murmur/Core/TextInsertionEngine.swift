import Foundation
import AppKit
import ApplicationServices
import CoreGraphics

/// Enum describing which path was used to insert text.
enum InsertionPath {
    case accessibility
    case clipboardPaste
}

/// Inserts formatted text at the cursor in any macOS application.
///
/// Primary path: AXUIElement `kAXSelectedTextAttribute` — directly sets text at cursor
/// without touching the clipboard.
///
/// Fallback path: Clipboard paste — writes text to NSPasteboard with a TransientType
/// marker and synthesizes Cmd+V. Original clipboard is restored after 150ms.
///
/// Known limitation: NSPasteboard `org.nspasteboard.TransientType` is best-effort.
/// Not all clipboard managers honor it (e.g., some third-party clipboard history tools
/// may capture the transient content anyway). This is a macOS ecosystem constraint,
/// not a bug in this implementation.
struct TextInsertionEngine {

    // MARK: - Public API

    /// Insert `text` at the current cursor position.
    ///
    /// - Returns: The `InsertionPath` that was actually used.
    @discardableResult
    func insert(_ text: String) -> InsertionPath {
        if tryAccessibilityInsert(text) {
            return .accessibility
        }
        clipboardPasteInsert(text)
        return .clipboardPaste
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

    // MARK: - Clipboard Paste Fallback

    private func clipboardPasteInsert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = snapshotPasteboard(pasteboard)

        // Write text with TransientType marker so clipboard managers ignore it.
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        // Synthesize Cmd+V (virtual key 9 = 'v').
        if let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 9, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }

        // Restore the original clipboard contents after paste has time to complete.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.restorePasteboard(pasteboard, from: snapshot)
        }
    }

    // MARK: - Clipboard Snapshot / Restore

    /// Captures all type/data pairs from `pb`.
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

    /// Restores `pb` to the state captured by `snapshotPasteboard`.
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
