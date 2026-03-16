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
    targets: [
        .executableTarget(
            name: "Typeness",
            path: "Typeness",
            sources: [
                "App/TypenessApp.swift",
                "App/SettingsStore.swift",
                "Core/AppState.swift",
                "Core/ModelManager.swift",
                "Input/HotkeyMonitor.swift",
                "UI/StatusItemView.swift",
                "UI/SettingsView.swift",
                "UI/OnboardingView.swift"
            ],
        )
    ]
)
