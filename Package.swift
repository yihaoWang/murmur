// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Murmur",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Murmur", targets: ["Murmur"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0")),
        .package(path: "LocalPackages/SwiftWhisper"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm/", exact: "2.30.6")
    ],
    targets: [
        .executableTarget(
            name: "Murmur",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "SwiftWhisper", package: "SwiftWhisper"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ],
            path: "Murmur",
            sources: [
                "App/MurmurApp.swift",
                "App/ContentView.swift",
                "App/SettingsStore.swift",
                "Core/AppState.swift",
                "Core/ModelManager.swift",
                "Core/AudioCaptureEngine.swift",
                "Core/TranscriptionEngine.swift",
                "Core/VAD.swift",
                "Core/PostProcessingEngine.swift",
                "Core/TextInsertionEngine.swift",
                "Core/DebugArchiver.swift",
                "Core/AppLogger.swift",
                "Input/HotkeyMonitor.swift",
                "UI/StatusItemView.swift",
                "UI/ConfirmInsertView.swift",
                "UI/SettingsView.swift",
                "UI/OnboardingView.swift",
                "UI/HotkeyRecorderView.swift",
                "UI/RecordingOverlayWindow.swift"
            ]
        ),
        .testTarget(
            name: "MurmurTests",
            dependencies: [
                "Murmur",
                .product(name: "SwiftWhisper", package: "SwiftWhisper"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ],
            path: "Tests/MurmurTests"
        )
    ]
)
