import Accelerate

/// Energy-based Voice Activity Detection gate using vDSP RMS computation.
/// Prevents whisper.cpp hallucinations by rejecting silence and short recordings.
enum VADGate {
    /// RMS energy threshold (normalized Float32). Approximately -40 dBFS.
    /// Audio below this threshold is considered silence.
    static let defaultThreshold: Float = 0.01

    /// Minimum recording duration in seconds. Whisper hallucinates on very short clips.
    static let minimumDurationSeconds: Double = 0.5

    /// Expected sample rate in Hz (16kHz mono Float32 from AudioCaptureEngine).
    static let sampleRate: Double = 16_000

    /// Returns true if the samples contain voice activity above the threshold.
    ///
    /// Rejects audio that is:
    /// - Too short (less than 0.5 seconds at 16kHz = fewer than 8000 frames)
    /// - Below the RMS energy threshold (silence or background noise only)
    ///
    /// - Parameters:
    ///   - samples: 16kHz mono Float32 PCM frames
    ///   - threshold: RMS energy threshold (default 0.01 ≈ -40 dBFS)
    static func hasVoiceActivity(samples: [Float], threshold: Float = defaultThreshold) -> Bool {
        let minimumFrames = Int(sampleRate * minimumDurationSeconds)
        guard samples.count >= minimumFrames else { return false }

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms > threshold
    }
}
