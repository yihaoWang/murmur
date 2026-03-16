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
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0"))
    ],
    targets: [
        .executableTarget(
            name: "Typeness",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts")
            ],
            path: "Typeness",
            sources: [
                "App/TypenessApp.swift",
                "App/SettingsStore.swift",
                "Core/AppState.swift",
                "Core/ModelManager.swift",
                "Input/HotkeyMonitor.swift",
                "UI/StatusItemView.swift",
                "UI/SettingsView.swift",
                "UI/OnboardingView.swift",
                "UI/HotkeyRecorderView.swift"
            ],
        )
    ]
)
