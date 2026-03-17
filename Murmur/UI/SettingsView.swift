import SwiftUI
import ServiceManagement
import KeyboardShortcuts

struct SettingsView: View {
    let appState: AppState
    @ObservedObject var settingsStore: SettingsStore
    let modelManager: ModelManager?
    let onModelChange: (WhisperModel) -> Void

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState, settingsStore: settingsStore)
                .tabItem { Label("General", systemImage: "gear") }
            ModelSettingsView(
                appState: appState,
                settingsStore: settingsStore,
                modelManager: modelManager,
                onModelChange: onModelChange
            )
                .tabItem { Label("Model", systemImage: "cpu") }
        }
        .frame(width: 450, height: 350)
    }
}

struct GeneralSettingsView: View {
    let appState: AppState
    @ObservedObject var settingsStore: SettingsStore

    private var launchAtLogin: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch at Login", isOn: Binding(
                    get: { SMAppService.mainApp.status == .enabled },
                    set: { newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            print("SMAppService error: \(error)")
                        }
                    }
                ))
            }

            Section("Hotkeys") {
                HotkeyRecorderRow(title: "Toggle Mode", name: .toggleMode, settingsStore: settingsStore)
                HotkeyRecorderRow(title: "Push to Talk", name: .pushToTalk, settingsStore: settingsStore)
            }

            Section("Permissions") {
                LabeledContent("Accessibility") {
                    Text(appState.accessibilityStatus == .granted ? "Granted" : "Not Granted")
                        .foregroundStyle(appState.accessibilityStatus == .granted ? .green : .red)
                }
                LabeledContent("Microphone") {
                    Text(appState.microphoneStatus == .granted ? "Granted" : "Not Granted")
                        .foregroundStyle(appState.microphoneStatus == .granted ? .green : .red)
                }
            }

            Section("Debug") {
                Toggle("Debug Mode (save recordings)", isOn: $settingsStore.debugModeEnabled)
                Toggle("Confirm Before Insert", isOn: $settingsStore.confirmBeforeInsert)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct ModelSettingsView: View {
    let appState: AppState
    @ObservedObject var settingsStore: SettingsStore
    let modelManager: ModelManager?
    let onModelChange: (WhisperModel) -> Void

    @State private var downloadConfirmModel: WhisperModel? = nil
    @State private var downloadingModel: WhisperModel? = nil
    @State private var downloadError: String? = nil

    private var selectedModel: WhisperModel {
        WhisperModel(rawValue: settingsStore.selectedWhisperModel) ?? .medium
    }

    var body: some View {
        Form {
            Section("Whisper Model") {
                ForEach(WhisperModel.allCases) { model in
                    ModelRow(
                        model: model,
                        isSelected: model == selectedModel,
                        isDownloaded: isDownloaded(model),
                        isDownloading: downloadingModel != nil,
                        downloadProgress: model == downloadingModel ? appState.modelDownloadProgress : nil,
                        onSelect: { selectModel(model) }
                    )
                }
            }

            if let error = downloadError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert(
            "Download Model",
            isPresented: Binding(
                get: { downloadConfirmModel != nil },
                set: { if !$0 { downloadConfirmModel = nil } }
            )
        ) {
            Button("Download") {
                if let model = downloadConfirmModel {
                    downloadAndSwitch(model)
                }
                downloadConfirmModel = nil
            }
            Button("Cancel", role: .cancel) {
                downloadConfirmModel = nil
            }
        } message: {
            if let model = downloadConfirmModel {
                Text("\"\(model.displayName)\" needs to be downloaded (\(model.sizeDescription)). Download now?")
            }
        }
    }

    private func isDownloaded(_ model: WhisperModel) -> Bool {
        guard modelManager != nil else { return false }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fullPath = appSupport.appendingPathComponent("Murmur/Models/\(model.fileName)")
        return FileManager.default.fileExists(atPath: fullPath.path)
    }

    private func selectModel(_ model: WhisperModel) {
        guard model != selectedModel else { return }
        if isDownloaded(model) {
            settingsStore.selectedWhisperModel = model.rawValue
            onModelChange(model)
        } else {
            downloadConfirmModel = model
        }
    }

    private func downloadAndSwitch(_ model: WhisperModel) {
        guard let manager = modelManager else { return }
        downloadError = nil
        downloadingModel = model
        Task {
            await MainActor.run { appState.isModelSwitching = true }
            do {
                try await manager.downloadWhisperModel(model)
                await MainActor.run {
                    settingsStore.selectedWhisperModel = model.rawValue
                    appState.isModelSwitching = false
                    downloadingModel = nil
                }
                onModelChange(model)
            } catch {
                await MainActor.run {
                    downloadError = "Download failed: \(error.localizedDescription)"
                    appState.isModelSwitching = false
                    downloadingModel = nil
                }
            }
        }
    }
}

struct ModelRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(model.displayName)
                            .fontWeight(isSelected ? .semibold : .regular)
                        Text(model.sizeDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let progress = downloadProgress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                } else if !isDownloaded {
                    Image(systemName: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
    }
}
