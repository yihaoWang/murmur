import XCTest
@testable import Murmur

final class LLMProcessorTests: XCTestCase {

    // LLM-01: PostProcessingEngine.format(_:) throws .notLoaded when model not loaded
    func testFormatThrowsWhenNotLoaded() async {
        let engine = PostProcessingEngine()
        do {
            _ = try await engine.format("測試")
            XCTFail("Expected PostProcessingError.notLoaded")
        } catch is PostProcessingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // LLM-02: Output contains no spaces between Chinese characters
    func testNoSpacesBetweenChineseChars() async throws {
        throw XCTSkip("Requires loaded LLM model (968 MB)")
    }

    // LLM-03: Progress callback is called with values in [0.0, 1.0] during model download
    func testModelLoadProgressReported() async throws {
        throw XCTSkip("Requires network and 968 MB download")
    }
}
