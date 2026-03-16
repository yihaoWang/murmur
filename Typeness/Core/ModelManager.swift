import Foundation

actor ModelManager {
    private let appState: AppState
    private let modelsDirectory: URL

    init(appState: AppState) {
        self.appState = appState
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.modelsDirectory = appSupport.appendingPathComponent("Typeness/Models", isDirectory: true)
    }

    func ensureModelsDirectory() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func whisperModelPath() -> URL {
        modelsDirectory.appendingPathComponent("ggml-large-v3-turbo.bin")
    }

    func llmModelDirectory() -> URL {
        modelsDirectory.appendingPathComponent("qwen3-1.7b", isDirectory: true)
    }

    func isWhisperModelDownloaded() -> Bool {
        FileManager.default.fileExists(atPath: whisperModelPath().path)
    }

    func checkAndUpdateModelStatus() async {
        if isWhisperModelDownloaded() {
            await MainActor.run {
                appState.isWhisperModelReady = true
            }
        }
    }

    func downloadWhisperModelIfNeeded() async throws {
        guard !isWhisperModelDownloaded() else {
            await MainActor.run { appState.isWhisperModelReady = true }
            return
        }
        try ensureModelsDirectory()

        let remoteURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
        let destination = whisperModelPath()

        let appStateRef = appState
        let delegate = DownloadProgressDelegate { progress in
            Task { @MainActor in
                appStateRef.modelDownloadProgress = progress
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (tempURL, _) = try await session.download(from: remoteURL)
        try FileManager.default.moveItem(at: tempURL, to: destination)

        await MainActor.run {
            appStateRef.modelDownloadProgress = nil  // Download complete
            appStateRef.isWhisperModelReady = true
        }
    }
}

final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: @Sendable (Double) -> Void

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        onProgress(progress)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Handled by the async download(from:) return
    }
}
