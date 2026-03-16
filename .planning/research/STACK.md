# Stack Research

**Domain:** Native macOS voice-to-text input tool (Swift)
**Researched:** 2026-03-16
**Confidence:** HIGH (core stack), MEDIUM (whisper.cpp SPM integration details)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| Swift | 6.0 | Primary language | Native macOS, full concurrency model (actors/async-await) needed for audio pipeline coordination |
| SwiftUI | macOS 14+ | Menu bar UI, settings popover | `MenuBarExtra` scene with `.menuBarExtraStyle(.window)` is the modern, boilerplate-free approach; replaces manual NSStatusItem + NSPopover wiring |
| whisper.cpp | v1.8.1 | Speech-to-text transcription | Fastest open-source Whisper port, Metal GPU acceleration on Apple Silicon, supports large-v3-turbo, same engine as existing Python version |
| mlx-swift-lm | 2.30.6 | Local LLM inference (post-processing) | Apple's own MLX framework, native Apple Silicon, same model ecosystem as the Python version (Qwen3-1.7B supported), officially endorsed by Apple at WWDC 2025 |
| AVFoundation / AVAudioEngine | system | Microphone capture | First-party, zero-dependency, supports installTap for real-time 16kHz mono PCM buffers; no sandboxing issues compared to third-party audio libraries |
| Accessibility API (ApplicationServices) | system | Text insertion at cursor | Only mechanism for inserting text into arbitrary apps without clipboard round-trip; `AXUIElementSetAttributeValue` with `kAXSelectedTextAttribute` |
| ServiceManagement (SMAppService) | macOS 13+ | Auto-start at login | Modern replacement for LaunchAgent plists and deprecated `SMLoginItemSetEnabled`; appears in System Settings > Login Items for user visibility |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeyboardShortcuts (sindresorhus) | latest (1.x) | User-configurable global hotkeys | Use for both toggle-mode (Shift+Cmd+A) and push-to-talk (Option+Space); supports `onKeyDown`/`onKeyUp` for push-to-talk; wraps Carbon `RegisterEventHotKey` which Apple has not deprecated for this use case |
| mlx-swift | 0.30.6 | Base MLX tensor framework | Required transitive dependency of mlx-swift-lm; don't use directly unless writing custom model code |
| Accelerate framework | system | Audio buffer format conversion | Needed for sample-rate conversion and float32 normalization of PCM buffers before feeding whisper.cpp |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Xcode 16+ | Build, debug, distribute | Required — SwiftPM cannot build Metal shaders (mlx-swift uses Metal); Metal shader compilation must go through Xcode |
| Swift Package Manager | Dependency management | Preferred over CocoaPods/Carthage for all dependencies; all listed libraries have SPM support |
| Instruments (Time Profiler + Metal System Trace) | Performance profiling | Critical for validating Metal GPU utilization during transcription and LLM inference |

## Installation

```swift
// Package.swift dependencies
dependencies: [
    // whisper.cpp — direct from official repo (whisper.spm is archived/deprecated)
    .package(url: "https://github.com/ggml-org/whisper.cpp", from: "1.8.1"),

    // MLX LLM inference
    .package(url: "https://github.com/ml-explore/mlx-swift-lm",
             .upToNextMinor(from: "2.30.6")),

    // Global hotkeys
    .package(url: "https://github.com/sindresorhus/KeyboardShortcuts",
             from: "1.0.0"),
],
targets: [
    .target(
        name: "Typeness",
        dependencies: [
            .product(name: "whisper", package: "whisper.cpp"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
        ]
    )
]
```

Note: All AVFoundation, Accessibility, and ServiceManagement APIs are system frameworks — no package dependency needed, just link in the Xcode target.

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| whisper.cpp direct SPM | SwiftWhisper (exPHAT) | Only if you want a higher-level Swift async API and don't need to control model loading lifecycle; SwiftWhisper wraps whisper.cpp but may lag behind upstream versions |
| whisper.cpp direct SPM | WhisperKit (argmaxinc) | If targeting App Store (no C++ bridging issues) or if you want structured concurrency built in; WhisperKit uses Core ML + ANE which may be faster on newer chips but adds a Core ML conversion step |
| mlx-swift-lm | llama.cpp via SPM | If you need models not in MLX format or want to share model weights with the Python version without conversion; mlx-swift-lm is preferred here because the Python app already uses MLX |
| KeyboardShortcuts | HotKey (soffes) | HotKey is simpler for non-configurable shortcuts; KeyboardShortcuts is better here because PROJECT.md requires user-configurable hotkeys in Settings |
| KeyboardShortcuts | CGEventTap directly | If you need Input Monitoring permission for keylogger-style detection; push-to-talk via CGEventTap requires Input Monitoring entitlement which is much harder to grant than Accessibility |
| AVAudioEngine | AudioToolbox Core Audio | Only if you need sub-millisecond latency or custom DSP; AVAudioEngine is sufficient for 16kHz voice recording and is vastly simpler to implement |
| SMAppService | LaunchAgent plist | LaunchAgent is appropriate only for background daemons that run without a UI; SMAppService.mainApp is the right API for a menu bar app that auto-starts |
| AXUIElement direct | AXSwift (tmandry) | AXSwift adds a thin Swift wrapper but is lightly maintained; direct AXUIElement calls are two lines and have no maintenance risk |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| whisper.spm (ggerganov/whisper.spm) | Explicitly archived and deprecated by the maintainer; README says "use the Swift package directly from whisper.cpp" | `ggml-org/whisper.cpp` direct SPM |
| Apple Speech Recognition (SFSpeechRecognizer) | Quality for Traditional Chinese is significantly worse than Whisper large-v3-turbo; requires internet connectivity for best results; PROJECT.md explicitly rules this out | whisper.cpp |
| NSWorkspace / pasteboard for text insertion | Clipboard-based insertion is disruptive (clobbers user's clipboard, visible paste flash) and unreliable in some apps | AXUIElement `kAXSelectedTextAttribute`; use clipboard only as fallback when AX is unavailable |
| App Sandbox entitlement | Accessibility API and global hotkeys require entitlements incompatible with the App Store sandbox; this app is direct distribution, so sandbox adds cost with no benefit | None — disable sandbox, use `com.apple.security.accessibility` entitlement |
| SMLoginItemSetEnabled | Deprecated since macOS 13; shows no entry in System Settings | SMAppService (ServiceManagement framework) |
| Combine for audio pipeline | Combine is being soft-deprecated in favor of Swift Concurrency; new code should use async/await + AsyncStream for audio buffer handling | Swift actors + AsyncStream |

## Stack Patterns by Variant

**For push-to-talk mode (Option+Space held):**
- Use `KeyboardShortcuts` `onKeyDown` to start recording, `onKeyUp` to stop
- Buffer audio in an actor-isolated queue
- No UI state needed beyond the menu bar icon animation

**For toggle mode (Shift+Cmd+A):**
- Use `KeyboardShortcuts` `onKeyDown` only
- Toggle recording state in a `@MainActor` observable state object
- Menu bar icon reflects active/idle state

**For Model downloading (first launch):**
- Use `URLSession` with `downloadTask` and `Progress` reporting
- Store models in `~/Library/Application Support/Typeness/`
- Show download progress in the menu bar icon via `NSStatusItem` title or badge

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| mlx-swift-lm 2.30.6 | mlx-swift 0.30.6 | These versions are released together; mlx-swift-lm version tracks mlx-swift minor version |
| whisper.cpp 1.8.1 | macOS 14+, Apple Silicon | Metal backend is auto-detected; no compile flags needed for basic Metal acceleration |
| KeyboardShortcuts 1.x | macOS 10.15+ | Push-to-talk `onKeyUp` requires macOS 13+ per docs; fine for this project's macOS 14+ requirement |
| SMAppService | macOS 13+ | Matches macOS 14+ target; do not use the old `SMLoginItemSetEnabled` path |
| Swift 6 strict concurrency | Xcode 16+ | whisper.cpp C API is not sendable-safe; wrap in an actor with `nonisolated(unsafe)` for the C context pointer |

## Sources

- [github.com/ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) — v1.8.1 confirmed, Metal support confirmed (HIGH confidence)
- [github.com/ggerganov/whisper.spm](https://github.com/ggerganov/whisper.spm) — Deprecation notice confirmed (HIGH confidence)
- [github.com/ml-explore/mlx-swift](https://github.com/ml-explore/mlx-swift) — v0.30.6 released Feb 10 2026 (HIGH confidence)
- [github.com/ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — v2.30.6 released Feb 18 2026, Qwen3 support confirmed (HIGH confidence)
- [github.com/sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — onKeyDown/onKeyUp confirmed, macOS 14+ compatible (HIGH confidence)
- [Apple WWDC 2025 — MLX on Apple Silicon](https://developer.apple.com/videos/play/wwdc2025/298/) — Apple's official endorsement of MLX for on-device LLM inference (HIGH confidence)
- [Apple Developer Docs — SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — Modern login item API (HIGH confidence)
- [nilcoalescing.com — MenuBarExtra SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — MenuBarExtra + window style pattern (MEDIUM confidence, WebSearch verified)
- WebSearch: "whisper.cpp Package.swift SPM product name 2025" — product name `whisper` confirmed from search but Package.swift content not directly read (MEDIUM confidence)

---
*Stack research for: Native macOS voice-to-text input tool (Typeness Swift rewrite)*
*Researched: 2026-03-16*
