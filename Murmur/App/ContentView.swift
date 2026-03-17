import SwiftUI

struct ContentView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: appState.menuBarIconName)
                .font(.system(size: 60))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)

            Text("Murmur")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("語音轉文字應用")
                .font(.headline)
                .foregroundStyle(.secondary)

            Divider()
                .padding(.vertical)

            // 狀態資訊
            VStack(alignment: .leading, spacing: 12) {
                StatusRow(title: "錄音狀態", value: appState.recordingState.description)
                StatusRow(title: "麥克風權限", value: appState.microphoneStatus.description)
                StatusRow(title: "輔助功能權限", value: appState.accessibilityStatus.description)
                StatusRow(title: "快捷鍵狀態", value: appState.hotkeyStatus.description)

                if let latency = appState.lastTranscriptionLatencyMs {
                    StatusRow(title: "最後轉錄延遲", value: String(format: "%.0f ms", latency))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.textBackgroundColor).opacity(0.5))
            .cornerRadius(10)

            // 最後的轉錄結果
            if !appState.lastTranscription.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最後轉錄：")
                        .font(.headline)
                    Text(appState.lastTranscription)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(8)
                }
            }

            Spacer()

            // 操作按鈕
            HStack(spacing: 16) {
                Button("設定") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .buttonStyle(.borderedProminent)

                if appState.recordingState == .idle {
                    Button("開始錄音") {
                        Task {
                            NotificationCenter.default.post(name: .hotkeyToggleFired, object: nil)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else if appState.recordingState == .recording {
                    Button("停止錄音") {
                        Task {
                            NotificationCenter.default.post(name: .hotkeyToggleFired, object: nil)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
        }
        .padding(40)
        .frame(minWidth: 500, minHeight: 400)
    }
}

struct StatusRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title + ":")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

// 擴展以提供狀態描述
extension AppState.RecordingState {
    var description: String {
        switch self {
        case .idle: return "閒置"
        case .recording: return "錄音中"
        case .transcribing: return "轉錄中"
        case .processing: return "處理中"
        }
    }
}

extension AppState.PermissionStatus {
    var description: String {
        switch self {
        case .unknown: return "未確定"
        case .granted: return "已授權"
        case .denied: return "已拒絕"
        case .revoked: return "已撤銷"
        }
    }
}

extension AppState.HotkeyStatus {
    var description: String {
        switch self {
        case .unregistered: return "未註冊"
        case .active: return "活躍"
        case .disabled: return "已停用"
        }
    }
}
