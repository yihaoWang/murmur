import Foundation

actor ModelManager {
    private let appState: AppState
    private let modelsDirectory: URL

    init(appState: AppState) {
        self.appState = appState
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.modelsDirectory = appSupport.appendingPathComponent("Murmur/Models", isDirectory: true)
    }

    func ensureModelsDirectory() throws {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    }

    func whisperModelPath(for model: WhisperModel) -> URL {
        modelsDirectory.appendingPathComponent(model.fileName)
    }

    func llmModelDirectory() -> URL {
        modelsDirectory.appendingPathComponent("qwen3-1.7b", isDirectory: true)
    }

    func isWhisperModelDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: whisperModelPath(for: model).path)
    }

    func checkAndUpdateModelStatus(for model: WhisperModel) async {
        if isWhisperModelDownloaded(model) {
            await MainActor.run {
                appState.isWhisperModelReady = true
            }
        }
    }

    func downloadAndLoadLLMIfNeeded(appState: AppState, engine: PostProcessingEngine) async throws {
        try await engine.load { progress in
            Task { @MainActor in
                appState.llmDownloadProgress = progress
            }
        }
        await MainActor.run {
            appState.llmDownloadProgress = nil
            appState.isLLMModelReady = true
        }
    }

    func downloadWhisperModel(_ model: WhisperModel) async throws {
        guard !isWhisperModelDownloaded(model) else {
            await MainActor.run { appState.isWhisperModelReady = true }
            return
        }
        try ensureModelsDirectory()

        let destination = whisperModelPath(for: model)

        let appStateRef = appState
        let delegate = DownloadProgressDelegate { progress in
            Task { @MainActor in
                appStateRef.modelDownloadProgress = progress
            }
        }

        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (tempURL, _) = try await session.download(from: model.downloadURL)
        try FileManager.default.moveItem(at: tempURL, to: destination)

        await MainActor.run {
            appStateRef.modelDownloadProgress = nil
            appStateRef.isWhisperModelReady = true
        }
    }

    func deleteWhisperModel(_ model: WhisperModel) throws {
        let path = whisperModelPath(for: model)
        if FileManager.default.fileExists(atPath: path.path) {
            try FileManager.default.removeItem(at: path)
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
