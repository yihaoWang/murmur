import XCTest
@testable import Murmur

final class PipelineIntegrationTests: XCTestCase {

    func testMenuBarIconNames() {
        let state = AppState()

        state.recordingState = .idle
        XCTAssertEqual(state.menuBarIconName, "mic")

        state.recordingState = .recording
        XCTAssertEqual(state.menuBarIconName, "mic.fill")

        state.recordingState = .transcribing
        XCTAssertEqual(state.menuBarIconName, "waveform")

        state.recordingState = .processing
        XCTAssertEqual(state.menuBarIconName, "ellipsis.circle")

        state.lastError = "test error"
        XCTAssertEqual(state.menuBarIconName, "exclamationmark.triangle")
    }

    func testLatencyPropertySet() {
        let state = AppState()
        XCTAssertNil(state.lastTranscriptionLatencyMs)
        state.lastTranscriptionLatencyMs = 123.4
        XCTAssertEqual(state.lastTranscriptionLatencyMs, 123.4)
    }

    func testPendingTranscriptionProperty() {
        let state = AppState()
        XCTAssertNil(state.pendingTranscription)
        state.pendingTranscription = "test"
        XCTAssertEqual(state.pendingTranscription, "test")
    }

    func testDebugArchiverCreatesFiles() throws {
        let frames = [Float](repeating: 0.1, count: 16000)
        XCTAssertNoThrow(
            try DebugArchiver.save(
                frames: frames,
                transcription: "test",
                formattedText: "test",
                latencyMs: 100.0,
                insertionPath: "accessibility"
            )
        )
        let dir = DebugArchiver.directory
        let contents = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let wavFiles = contents.filter { $0.pathExtension == "wav" }
        let jsonFiles = contents.filter { $0.pathExtension == "json" }
        XCTAssertFalse(wavFiles.isEmpty, "Expected WAV file to be created")
        XCTAssertFalse(jsonFiles.isEmpty, "Expected JSON file to be created")

        // Clean up
        for file in contents {
            try? FileManager.default.removeItem(at: file)
        }
    }

    func testDebugModeTogglePersists() throws {
        throw XCTSkip("Requires @AppStorage runtime; covered by settings UI")
    }

    func testConfirmBeforeInsertPersists() throws {
        throw XCTSkip("Requires @AppStorage runtime; covered by settings UI")
    }
}
