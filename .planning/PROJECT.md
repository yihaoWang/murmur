# Typeness (Swift)

## What This Is

A native macOS voice-to-text input tool rebuilt in Swift from an existing Python implementation. Users press a global hotkey, speak in Traditional Chinese, and the transcribed + formatted text is automatically inserted at the cursor position in any application. Menu bar app with SwiftUI-based settings UI.

## Core Value

Fast, reliable voice-to-text input that feels native to macOS — press hotkey, speak, text appears at cursor with correct punctuation and formatting.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Global hotkey activation (toggle mode: Shift+Command+A, push-to-talk: Option+Space)
- [ ] Audio recording via system microphone at 16kHz mono
- [ ] Speech-to-text via whisper.cpp with Metal GPU acceleration (large-v3-turbo model)
- [ ] Text post-processing via MLX Swift with local LLM (Qwen3-1.7B) for punctuation and formatting
- [ ] Text insertion at cursor via macOS Accessibility API, clipboard fallback
- [ ] Menu bar app with SwiftUI popover/settings
- [ ] Settings: hotkey configuration, auto-start at login, debug mode, confirm-before-insert
- [ ] Debug mode: save recordings as WAV + JSON
- [ ] Auto-start at login via LaunchAgent
- [ ] Model downloading/loading with progress indicator in menu bar

### Out of Scope

- iOS/iPadOS support — macOS only for v1
- Cloud-based speech recognition — all processing is local
- Languages other than Traditional Chinese — can be added later
- App Store distribution — direct distribution for v1

## Context

- Rewrite of existing Python app (github.com/yihaoWang/typeness) bundled with PyInstaller
- Python version uses Whisper large-v3-turbo + Qwen3-1.7B via MLX/PyTorch
- Primary motivation: performance — faster transcription, lower latency, better resource usage
- Target: Apple Silicon Macs (M1+)
- Existing app is already installed at /Applications/Typeness.app (Python version)

## Constraints

- **Platform**: macOS 14+ (Sonoma), Apple Silicon only
- **STT Engine**: whisper.cpp with Metal acceleration for best performance
- **LLM Engine**: MLX Swift for local LLM inference
- **UI Framework**: SwiftUI for modern, smooth macOS UI
- **Privacy**: All processing must be local — no data sent to external services
- **Feature parity**: Must match all features of the existing Python version

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| whisper.cpp over Apple Speech | Better quality for Chinese, consistent with existing Whisper model | — Pending |
| MLX Swift for LLM | Native Apple Silicon acceleration, same model ecosystem as Python version | — Pending |
| SwiftUI over AppKit | Smoother UI, modern macOS design, less boilerplate | — Pending |
| Menu bar app style | Matches existing Python app behavior (LSUIElement), unobtrusive | — Pending |

---
*Last updated: 2026-03-16 after initialization*
