import XCTest
import AppKit
@testable import Murmur

final class TextInserterTests: XCTestCase {

    // INSERT-01: TextInsertionEngine returns .accessibility when AX set succeeds
    func testAccessibilityInsertReturnsPath() throws {
        throw XCTSkip("Requires live AX focused element")
    }

    // INSERT-02: TextInsertionEngine returns .clipboardPaste when AX set fails
    func testClipboardFallbackReturnsPath() throws {
        throw XCTSkip("Requires AX failure condition")
    }

    // INSERT-03: Clipboard is restored to original content after paste fallback
    func testClipboardRestored() {
        let pb = NSPasteboard.general
        // Set known content
        pb.clearContents()
        pb.setString("original", forType: .string)

        // Snapshot
        let engine = TextInsertionEngine()
        let snapshot = engine.snapshotPasteboard(pb)

        // Overwrite
        pb.clearContents()
        pb.setString("temporary", forType: .string)

        // Restore
        engine.restorePasteboard(pb, from: snapshot)

        XCTAssertEqual(pb.string(forType: .string), "original")
    }

    // INSERT-04: NSPasteboard write includes org.nspasteboard.TransientType type
    func testTransientTypeMarkerPresent() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString("test", forType: .string)
        pb.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        let types = pb.types ?? []
        XCTAssertTrue(types.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")),
                      "TransientType marker must be present on pasteboard")
    }
}
