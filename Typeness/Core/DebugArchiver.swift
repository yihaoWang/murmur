import AVFoundation
import Foundation

struct DebugArchiver {
    static let directory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Typeness/DebugRecordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    struct SessionMetadata: Codable {
        let timestamp: Date
        let transcription: String
        let formattedText: String
        let latencyMs: Double
        let audioFrameCount: Int
        let insertionPath: String
    }

    static func save(
        frames: [Float],
        transcription: String,
        formattedText: String,
        latencyMs: Double,
        insertionPath: String
    ) throws {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let base = formatter.string(from: timestamp)

        let wavURL = directory.appendingPathComponent("\(base).wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(forWriting: wavURL, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames.count))!
        buffer.frameLength = buffer.frameCapacity
        let channelData = buffer.floatChannelData![0]
        for (i, sample) in frames.enumerated() {
            channelData[i] = sample
        }
        try file.write(from: buffer)

        let meta = SessionMetadata(
            timestamp: timestamp,
            transcription: transcription,
            formattedText: formattedText,
            latencyMs: latencyMs,
            audioFrameCount: frames.count,
            insertionPath: insertionPath
        )
        let jsonURL = directory.appendingPathComponent("\(base).json")
        let data = try JSONEncoder().encode(meta)
        try data.write(to: jsonURL)
    }
}
