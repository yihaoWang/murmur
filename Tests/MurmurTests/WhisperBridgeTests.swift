import XCTest
@testable import Murmur

final class WhisperBridgeTests: XCTestCase {
    func testTranscribeThrowsWhenNotLoaded() async throws {
        let engine = TranscriptionEngine()
        do {
            _ = try await engine.transcribe(audioFrames: [1.0])
            XCTFail("Expected TranscriptionError.notLoaded to be thrown")
        } catch TranscriptionError.notLoaded {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeEmptyAudioThrows() async throws {
        // Requires a loaded model — skip in test environment where model file is not present.
        // The guard logic for emptyAudio is verified here as a unit test if model were available.
        throw XCTSkip("Requires whisper model file at ~/Library/Application Support/Murmur/Models/ggml-large-v3-turbo.bin")
    }
}
