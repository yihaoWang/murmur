import AVFoundation

enum AudioError: Error {
    case converterCreationFailed
    case microphonePermissionDenied
    case engineStartFailed
}

actor AudioCaptureEngine {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    let maxFrames = 480_000  // 30 seconds at 16kHz

    func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func start() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterCreationFailed
        }
        converter = conv
        samples.removeAll()

        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in
            Task { await self?.process(buffer: buffer) }
        }

        do {
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            throw AudioError.engineStartFailed
        }
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * (16_000.0 / buffer.format.sampleRate)
        )
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount + 16
        ) else { return }

        var error: NSError?
        var filled = false
        converter.convert(to: outBuffer, error: &error) { _, status in
            if filled { status.pointee = .noDataNow; return nil }
            filled = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let data = outBuffer.floatChannelData?[0] else { return }
        let newSamples = Array(UnsafeBufferPointer(start: data, count: Int(outBuffer.frameLength)))
        let remaining = maxFrames - samples.count
        if remaining > 0 {
            samples.append(contentsOf: newSamples.prefix(remaining))
        }
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return samples
    }
}
