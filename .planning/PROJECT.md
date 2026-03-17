# Typeness (Swift)

## What This Is

A native macOS voice-to-text input tool rebuilt in Swift from an existing Python implementation. Users press a global hotkey, speak in Traditional Chinese, and the transcribed + formatted text is automatically inserted at the cursor position in any application. Runs as a menu bar app with SwiftUI settings, debug archiving, and confirm-before-insert mode.

## Core Value

Fast, reliable voice-to-text input that feels native to macOS — press hotkey, speak, text appears at cursor with correct punctuation and formatting.

## Current State

Shipped v1.0 MVP with 1,160 LOC Swift across 5 phases.

**Tech stack:** SwiftUI, AVAudioEngine, whisper.cpp (SwiftWhisper), MLX Swift (MLXLLM), CGEventTap, Accessibility API
**Target:** macOS 14+ (Sonoma), Apple Silicon (M1+)

**Architecture:**
- `TypenessApp` — App entry point, pipeline orchestration, MenuBarExtra
- `HotkeyMonitor` — CGEventTap global hotkeys (toggle + push-to-talk)
- `AudioCaptureEngine` — AVAudioEngine → 16kHz mono Float32
- `TranscriptionEngine` — SwiftWhisper actor with VAD gate
- `PostProcessingEngine` — Qwen3-1.7B TC punctuation formatting
- `TextInsertionEngine` — AX primary, clipboard paste fallback
- `ModelManager` — Whisper model download with progress
- `DebugArchiver` — WAV + JSON session archiving
- `AppState` — Observable state (recording, progress, errors)
- `SettingsStore` — @AppStorage persistence

## Requirements

### Validated

- ✓ Global hotkey activation (toggle + push-to-talk) — v1.0
- ✓ Audio recording via system microphone at 16kHz mono — v1.0
- ✓ Speech-to-text via whisper.cpp with CoreML/Accelerate (large-v3-turbo) — v1.0
- ✓ Text post-processing via MLX Swift with Qwen3-1.7B — v1.0
- ✓ Text insertion at cursor via Accessibility API, clipboard fallback — v1.0
- ✓ Menu bar app with SwiftUI settings — v1.0
- ✓ Settings: hotkey configuration, auto-start at login, debug mode, confirm-before-insert — v1.0
- ✓ Debug mode: save recordings as WAV + JSON — v1.0
- ✓ Auto-start at login via SMAppService — v1.0
- ✓ Model downloading/loading with progress indicator — v1.0

### Active

(None — next milestone TBD)

### Out of Scope

- iOS/iPadOS support — macOS only
- Cloud-based speech recognition — all processing is local
- Languages other than Traditional Chinese — can be added later
- App Store distribution — sandbox incompatible with AX API + global hotkeys
- Real-time streaming transcription — Whisper is a batch model
- Meeting recording/transcription — focused on dictation input

## Constraints

- **Platform**: macOS 14+ (Sonoma), Apple Silicon only
- **STT Engine**: whisper.cpp via SwiftWhisper (CoreML for ANE, Accelerate for CPU BLAS)
- **LLM Engine**: MLX Swift (MLXLLM) for local LLM inference
- **UI Framework**: SwiftUI for modern macOS UI
- **Privacy**: All processing must be local — no data sent to external services
- **Sandbox**: Disabled — CGEventTap requires unsandboxed execution

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| whisper.cpp over Apple Speech | Better quality for Chinese, consistent with existing Whisper model | ✓ Good |
| MLX Swift for LLM | Native Apple Silicon acceleration, same model ecosystem as Python version | ✓ Good |
| SwiftUI over AppKit | Smoother UI, modern macOS design, less boilerplate | ✓ Good |
| Menu bar app style | Matches existing Python app behavior (LSUIElement), unobtrusive | ✓ Good |
| SwiftWhisper over direct whisper.cpp SPM | Simpler Swift API, confirmed product name | ✓ Good |
| CoreML/Accelerate over Metal GPU | SwiftWhisper bundles whisper.cpp that predates ggml-metal | ✓ Good (ANE works well) |
| MLXLLM product name (not LLM) | Research doc was wrong, corrected during execution | ⚠️ Revisit docs |
| KeyboardShortcuts 1.15.0 (not 2.x) | Avoids #Preview macro issues in swift build | ✓ Good |
| App sandbox disabled | Required for CGEventTap; microphone entitlement added | ✓ Good |
| PendingDebugContext for confirm path | Stores audio frames for debug archiving in confirm-before-insert flow | ✓ Good |

---
*Last updated: 2026-03-17 after v1.0 milestone*
