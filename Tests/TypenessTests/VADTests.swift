import XCTest
@testable import Typeness

final class VADTests: XCTestCase {
    func testSilenceRejected() throws {
        // 16000 frames of silence (0.0) — below threshold
        XCTAssertFalse(VADGate.hasVoiceActivity(samples: [Float](repeating: 0.0, count: 16000)))
    }

    func testShortRecordingRejected() throws {
        // 4000 frames (0.25s) of loud audio — too short, below minimumDurationSeconds (0.5s = 8000 frames)
        XCTAssertFalse(VADGate.hasVoiceActivity(samples: [Float](repeating: 0.5, count: 4000)))
    }

    func testLoudAudioAccepted() throws {
        // 16000 frames (1.0s) of 0.5 amplitude — RMS = 0.5, well above threshold 0.01
        XCTAssertTrue(VADGate.hasVoiceActivity(samples: [Float](repeating: 0.5, count: 16000)))
    }
}
