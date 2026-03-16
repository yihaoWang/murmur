import XCTest
@testable import Typeness

final class VADTests: XCTestCase {
    func testSilenceRejected() throws {
        // STUB: Plan 02-02 will implement after VADGate exists
        // Verify: VADGate.hasVoiceActivity(samples: [Float](repeating: 0.0, count: 16000)) == false
        throw XCTSkip("Awaiting VADGate implementation in plan 02-02")
    }

    func testShortRecordingRejected() throws {
        // STUB: Plan 02-02 will implement
        // Verify: VADGate.hasVoiceActivity(samples: [Float](repeating: 0.5, count: 4000)) == false
        throw XCTSkip("Awaiting VADGate implementation in plan 02-02")
    }

    func testLoudAudioAccepted() throws {
        // STUB: Plan 02-02 will implement
        // Verify: VADGate.hasVoiceActivity(samples: [Float](repeating: 0.5, count: 16000)) == true
        throw XCTSkip("Awaiting VADGate implementation in plan 02-02")
    }
}
