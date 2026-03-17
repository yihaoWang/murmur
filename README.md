# Murmur

Native macOS voice-to-text input tool with Traditional Chinese focus, local speech recognition, and local LLM formatting. Press a hotkey, speak, and the formatted text is inserted at the cursor in any app.

All processing is on-device — no data is sent to external services.

## Features

- Global hotkey activation with toggle and push-to-talk modes
- Speech-to-text via whisper.cpp (large-v3-turbo model, CoreML/Accelerate for Apple Silicon)
- Text formatting via local LLM (Qwen3-1.7B via MLX Swift) — adds punctuation and corrects Traditional Chinese
- Text insertion at cursor in any app via Accessibility API with clipboard paste fallback
- Menu bar app with SwiftUI settings panel
- Confirm-before-insert mode for reviewing transcription before committing
- Debug mode with WAV and JSON session archiving
- Auto-start at login via SMAppService
- 100% local processing — no network requests, no telemetry

## Install

Download the latest DMG from [GitHub Releases](https://github.com/yihaoWang/murmur/releases), open it, and drag Murmur to Applications.

On first launch, grant Accessibility permissions in System Settings > Privacy & Security > Accessibility, and allow microphone access when prompted.

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1 or later)

Sandbox is disabled. The app requires Accessibility permissions (for cursor text insertion and CGEventTap global hotkeys) and microphone access.

## Building

```
swift build
```

To build a standalone app bundle and DMG:

```
bash scripts/build-app.sh
```

The app can also be opened in Xcode.

## Architecture

| Component | Role |
|-----------|------|
| `MurmurApp` | App entry point, pipeline orchestration, MenuBarExtra |
| `HotkeyMonitor` | CGEventTap global hotkeys (toggle and push-to-talk) |
| `AudioCaptureEngine` | AVAudioEngine input pipeline, converts to 16kHz mono Float32 |
| `TranscriptionEngine` | SwiftWhisper actor with VAD gate, runs Whisper inference |
| `PostProcessingEngine` | Qwen3-1.7B via MLXLLM, adds Traditional Chinese punctuation |
| `TextInsertionEngine` | AX API primary insertion, clipboard paste fallback |
| `ModelManager` | Whisper model download with progress tracking |
| `DebugArchiver` | Saves WAV recordings and JSON metadata per session |
| `AppState` | Observable state — recording status, progress, errors |
| `SettingsStore` | @AppStorage-backed persistent settings |

## Tech Stack

- SwiftUI — menu bar app UI and settings panel
- AVAudioEngine — microphone capture
- SwiftWhisper (whisper.cpp) — speech recognition with CoreML and Accelerate backends
- MLX Swift (MLXLLM) — local LLM inference on Apple Silicon
- CGEventTap — global hotkey monitoring
- Accessibility API — text insertion at cursor in third-party apps

## Privacy

All speech recognition and text processing happens locally on device. No audio, transcription, or usage data is sent to any external service.

## License

TBD
