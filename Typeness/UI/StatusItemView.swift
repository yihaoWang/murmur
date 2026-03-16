import SwiftUI

struct StatusItemView: View {
    @Environment(\.openSettings) private var openSettings
    let appState: AppState
    let modelManager: ModelManager?

    var body: some View {
        VStack(spacing: 12) {
            Text("Typeness")
                .font(.headline)

            if let progress = appState.modelDownloadProgress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("Downloading models... \(Int(progress * 100))%")
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

            Divider()

            Button("Settings...") {
                NSApp.setActivationPolicy(.regular)
                openSettings()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.setActivationPolicy(.accessory)
                }
            }

            Button("Quit Typeness") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 240)
    }
}
