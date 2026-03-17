import XCTest
import AVFoundation
@testable import Murmur

final class AudioCaptureTests: XCTestCase {

    func testTargetFormatIs16kHzMonoFloat32() async {
        let engine = AudioCaptureEngine()
        let format = await engine.targetFormat
        XCTAssertEqual(format.sampleRate, 16_000.0)
        XCTAssertEqual(format.channelCount, 1)
        XCTAssertEqual(format.commonFormat, .pcmFormatFloat32)
    }

    func testMaxFramesCapped() async {
        let engine = AudioCaptureEngine()
        let maxFrames = await engine.maxFrames
        XCTAssertEqual(maxFrames, 480_000)
    }

    func testPermissionCheckCalledBeforeStart() async throws {
        // Skipped: requires real microphone hardware or AVCaptureDevice mock
        throw XCTSkip("Requires real microphone hardware or AVCaptureDevice mock")
    }
}
