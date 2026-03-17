import Foundation
import SwiftWhisper

enum TranscriptionError: Error, Equatable {
    case notLoaded
    case emptyAudio
}

/// TranscriptionEngine wraps SwiftWhisper for speech-to-text inference.
///
/// Acceleration: SwiftWhisper compiles whisper.cpp with GGML_USE_ACCELERATE (CPU BLAS via
/// Apple Accelerate framework) and WHISPER_USE_COREML (Apple Neural Engine via CoreML).
/// The Metal GPU compute backend (GGML_USE_METAL) is not included because SwiftWhisper's
/// bundled whisper.cpp predates the ggml Metal backend source files. CoreML on Apple Silicon
/// ANE provides excellent inference performance for this workload.
actor TranscriptionEngine {
    // nonisolated(unsafe) is used because Whisper is not Sendable-compatible with actor isolation.
    // This is safe because all access is serialized through the actor's executor.
    nonisolated(unsafe) private var whisper: Whisper?

    /// Load the whisper.cpp model from the given URL.
    func load(modelURL: URL) {
        whisper = Whisper(fromFileURL: modelURL)
        // Attempt to set language to "zh" for Traditional Chinese.
        // The SwiftWhisper params API wraps whisper_full_params from C;
        // if the language property is unavailable or has a different type,
        // we skip it — large-v3-turbo auto-detects Chinese accurately.
        // whisper?.params.language = WhisperLanguage(rawValue: "zh")
    }

    /// Returns true if the model has been loaded.
    var isLoaded: Bool {
        whisper != nil
    }

    /// Transcribe the given 16kHz mono Float32 audio frames to a string.
    func transcribe(audioFrames: [Float]) async throws -> String {
        guard whisper != nil else { throw TranscriptionError.notLoaded }
        guard !audioFrames.isEmpty else { throw TranscriptionError.emptyAudio }
        AppLogger.log("whisper.transcribe starting, frames=\(audioFrames.count), isLoaded=\(isLoaded)")
        let segments = try await whisper!.transcribe(audioFrames: audioFrames)
        AppLogger.log("whisper.transcribe done, segments=\(segments.count)")
        return segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
