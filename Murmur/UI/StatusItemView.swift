import SwiftUI

struct StatusItemView: View {
    @Environment(\.openSettings) private var openSettings
    let appState: AppState
    let modelManager: ModelManager?

    var body: some View {
        VStack(spacing: 12) {
            Text("Murmur")
                .font(.headline)

            if let progress = appState.modelDownloadProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("Downloading models... \(Int(progress * 100))%")
                    .font(.caption)
            } else if let llmProgress = appState.llmDownloadProgress {
                ProgressView(value: llmProgress)
                    .progressViewStyle(.linear)
                Text("Downloading LLM... \(Int(llmProgress * 100))%")
                    .font(.caption)
            } else if !appState.isWhisperModelReady {
                Text("Models not downloaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Download") {
                    guard let manager = modelManager else { return }
                    Task {
                        try? await manager.downloadWhisperModelIfNeeded()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            switch appState.recordingState {
            case .idle: EmptyView()
            case .recording:
                Label("Recording...", systemImage: "mic.fill")
                    .foregroundStyle(.red)
            case .transcribing:
                Label("Transcribing...", systemImage: "waveform")
            case .processing:
                Label("Processing...", systemImage: "ellipsis.circle")
            }

            if let ms = appState.lastTranscriptionLatencyMs {
                Text(String(format: "Last: %.0f ms", ms))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = appState.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Settings...") {
                NSApp.setActivationPolicy(.regular)
                openSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }

            Button("Quit Murmur") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 240)
        .sheet(isPresented: Binding(
            get: { appState.pendingTranscription != nil },
            set: { if !$0 {
                appState.pendingTranscription = nil
                appState.pendingDebugContext = nil
                appState.recordingState = .idle
            }}
        )) {
            ConfirmInsertView(
                text: appState.pendingTranscription ?? "",
                onConfirm: { text in
                    TextInsertionEngine().insert(text)
                    if let ctx = appState.pendingDebugContext {
                        try? DebugArchiver.save(
                            frames: ctx.frames,
                            transcription: ctx.rawTranscription,
                            formattedText: text,
                            latencyMs: ctx.latencyMs,
                            insertionPath: "confirmInsert"
                        )
                    }
                    appState.pendingDebugContext = nil
                    appState.pendingTranscription = nil
                    appState.recordingState = .idle
                },
                onCancel: {
                    appState.pendingDebugContext = nil
                    appState.pendingTranscription = nil
                    appState.recordingState = .idle
                }
            )
        }
    }
}
