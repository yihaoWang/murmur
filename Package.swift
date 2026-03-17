// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Typeness",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Typeness", targets: ["Typeness"])
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0")),
        .package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm/", exact: "2.30.6")
    ],
    targets: [
        .executableTarget(
            name: "Typeness",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                .product(name: "SwiftWhisper", package: "SwiftWhisper"),
                .product(name: "LLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ],
            path: "Typeness",
            sources: [
                "App/TypenessApp.swift",
                "App/SettingsStore.swift",
                "Core/AppState.swift",
                "Core/ModelManager.swift",
                "Core/AudioCaptureEngine.swift",
                "Core/TranscriptionEngine.swift",
                "Core/VAD.swift",
                "Core/PostProcessingEngine.swift",
                "Core/TextInsertionEngine.swift",
                "Input/HotkeyMonitor.swift",
                "UI/StatusItemView.swift",
                "UI/SettingsView.swift",
                "UI/OnboardingView.swift",
                "UI/HotkeyRecorderView.swift"
            ]
        ),
        .testTarget(
            name: "TypenessTests",
            dependencies: [
                "Typeness",
                .product(name: "SwiftWhisper", package: "SwiftWhisper"),
                .product(name: "LLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ],
            path: "Tests/TypenessTests"
        )
    ]
)
