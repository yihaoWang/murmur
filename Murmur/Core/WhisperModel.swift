import Foundation

enum WhisperModel: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case largev3turbo = "large-v3-turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .largev3turbo: "Large v3 Turbo"
        }
    }

    var fileName: String {
        "ggml-\(rawValue).bin"
    }

    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    var sizeDescription: String {
        switch self {
        case .small: "466 MB"
        case .medium: "1.5 GB"
        case .largev3turbo: "1.6 GB"
        }
    }
}
