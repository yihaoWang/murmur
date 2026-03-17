import XCTest
@testable import Murmur

final class WhisperCrashTest: XCTestCase {

    func testWhisperTranscribeSilenceDoesNotCrash() async throws {
        let modelPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Murmur/Models/ggml-large-v3-turbo.bin")

        guard FileManager.default.fileExists(atPath: modelPath.path) else {
            throw XCTSkip("Whisper model not downloaded at \(modelPath.path)")
        }

        let engine = TranscriptionEngine()
        await engine.load(modelURL: modelPath)

        let isLoaded = await engine.isLoaded
        XCTAssertTrue(isLoaded, "TranscriptionEngine should be loaded")

        // Generate 2 seconds of sine wave at 440Hz (not silence, to pass VAD if needed)
        let sampleRate: Float = 16000
        let duration: Float = 2.0
        let frameCount = Int(sampleRate * duration)
        let frames: [Float] = (0..<frameCount).map { i in
            sin(2.0 * .pi * 440.0 * Float(i) / sampleRate) * 0.5
        }

        // This is where the crash happens — if whisper_full aborts, this test will crash too
        let text = try await engine.transcribe(audioFrames: frames)
        print("Transcription result: '\(text)'")
        // We don't care about the content, just that it didn't crash
    }
}
