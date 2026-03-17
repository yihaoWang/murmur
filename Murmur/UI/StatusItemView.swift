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
                    let model = WhisperModel(rawValue: UserDefaults.standard.string(forKey: "selectedWhisperModel") ?? "") ?? .medium
                    Task {
                        appState.isModelSwitching = true
                        try? await manager.downloadWhisperModel(model)
                        appState.isModelSwitching = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            switch appState.recordingState {
            case .idle:
                Button {
                    NotificationCenter.default.post(name: .hotkeyToggleFired, object: nil)
                } label: {
                    Label("Start Recording", systemImage: "mic.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            case .recording:
                Button {
                    NotificationCenter.default.post(name: .hotkeyToggleFired, object: nil)
                } label: {
                    Label("Stop Recording", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            case .transcribing:
                Label("Transcribing...", systemImage: "waveform")
            case .processing:
                Label("Processing...", systemImage: "ellipsis.circle")
            }

            if !appState.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last transcription:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(appState.lastTranscription)
                        .font(.caption)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let ms = appState.lastTranscriptionLatencyMs {
                Text(String(format: "%.0f ms", ms))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if appState.accessibilityStatus != .granted {
                Label("Accessibility required", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Button("Grant Permission") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if let error = appState.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Divider()

            Button("Settings...") {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
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
