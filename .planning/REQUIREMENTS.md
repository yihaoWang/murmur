# Requirements: Typeness (Swift)

**Defined:** 2026-03-16
**Core Value:** Fast, reliable voice-to-text input that feels native to macOS — press hotkey, speak, text appears at cursor with correct punctuation and formatting.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Audio Capture

- [x] **AUDIO-01**: App can record microphone audio at 16kHz mono Float32 PCM format
- [x] **AUDIO-02**: App requests microphone permission on first use with clear explanation
- [x] **AUDIO-03**: Audio capture starts/stops in response to hotkey events with < 100ms latency

### Speech Recognition

- [x] **STT-01**: App transcribes audio using whisper.cpp with Metal GPU acceleration
- [ ] **STT-02**: App downloads whisper large-v3-turbo model on first launch with progress indicator
- [x] **STT-03**: App applies VAD gating to prevent hallucinated output on silence/noise
- [ ] **STT-04**: App displays transcription latency in menu bar or status area

### LLM Post-Processing

- [ ] **LLM-01**: App post-processes transcribed text using MLX Swift with Qwen3-1.7B model
- [ ] **LLM-02**: Post-processing formats text according to TC conventions (no spaces between characters)
- [ ] **LLM-03**: App downloads LLM model on first launch with progress indicator

### Text Insertion

- [ ] **INSERT-01**: App inserts text at cursor position via macOS Accessibility API (AXUIElement)
- [ ] **INSERT-02**: App falls back to clipboard paste when AX insertion fails (Electron apps, terminals)
- [ ] **INSERT-03**: App saves and restores clipboard contents around paste fallback
- [ ] **INSERT-04**: Clipboard paste uses NSPasteboard TransientType marker

### Global Hotkeys

- [x] **HOTKEY-01**: User can activate voice input via toggle mode (default: Shift+Option+Space)
- [x] **HOTKEY-02**: User can activate voice input via push-to-talk (default: Option+Space)
- [x] **HOTKEY-03**: User can configure hotkey bindings in settings
- [x] **HOTKEY-04**: Hotkeys work globally across all applications
- [x] **HOTKEY-05**: Hotkey events are suppressed (not passed to active app) to prevent unwanted input

### UI / Menu Bar

- [x] **UI-01**: App runs as menu bar app (LSUIElement) with no dock icon
- [ ] **UI-02**: Menu bar icon shows status states (idle, recording, processing, error)
- [x] **UI-03**: App displays SwiftUI settings window accessible from menu bar
- [x] **UI-04**: Menu bar shows model loading progress on first launch

### System Integration

- [x] **SYS-01**: App can auto-start at login via SMAppService
- [x] **SYS-02**: App presents permission onboarding for Accessibility and Microphone on first launch
- [x] **SYS-03**: App checks Accessibility trust status on startup and prompts if revoked

### Debug & Polish

- [ ] **DEBUG-01**: User can enable debug mode in settings
- [ ] **DEBUG-02**: Debug mode saves recordings as WAV files with JSON metadata
- [ ] **DEBUG-03**: User can enable confirm-before-insert mode in settings
- [ ] **DEBUG-04**: Confirm mode shows transcribed text for review before insertion

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Features

- **ADV-01**: Context-aware insertion (read selected text/clipboard before transcription)
- **ADV-02**: Multiple Whisper model size options (fast/balanced/accurate)
- **ADV-03**: Custom vocabulary for proper nouns and technical terms
- **ADV-04**: Multiple language support beyond Traditional Chinese
- **ADV-05**: Custom LLM prompts for different formatting modes

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time streaming transcription | Whisper is a batch model; faking streaming adds complexity without UX benefit |
| Cloud-based processing | Core value is local/private processing |
| iOS/iPadOS support | macOS only for v1 |
| App Store distribution | Direct distribution; sandbox incompatible with AX API + global hotkeys |
| Meeting recording/transcription | Different use case; focused on dictation input |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| UI-01 | Phase 1 | Complete |
| UI-03 | Phase 1 | Complete |
| UI-04 | Phase 1 | Complete |
| SYS-01 | Phase 1 | Complete |
| SYS-02 | Phase 1 | Complete |
| SYS-03 | Phase 1 | Complete |
| HOTKEY-01 | Phase 1 | Complete |
| HOTKEY-02 | Phase 1 | Complete |
| HOTKEY-03 | Phase 1 | Complete |
| HOTKEY-04 | Phase 1 | Complete |
| HOTKEY-05 | Phase 1 | Complete |
| AUDIO-01 | Phase 2 | Complete |
| AUDIO-02 | Phase 2 | Complete |
| AUDIO-03 | Phase 2 | Complete |
| STT-01 | Phase 2 | Complete |
| STT-02 | Phase 2 | Pending |
| STT-03 | Phase 2 | Complete |
| LLM-01 | Phase 3 | Pending |
| LLM-02 | Phase 3 | Pending |
| LLM-03 | Phase 3 | Pending |
| INSERT-01 | Phase 3 | Pending |
| INSERT-02 | Phase 3 | Pending |
| INSERT-03 | Phase 3 | Pending |
| INSERT-04 | Phase 3 | Pending |
| UI-02 | Phase 4 | Pending |
| STT-04 | Phase 4 | Pending |
| DEBUG-01 | Phase 4 | Pending |
| DEBUG-02 | Phase 4 | Pending |
| DEBUG-03 | Phase 4 | Pending |
| DEBUG-04 | Phase 4 | Pending |

**Coverage:**
- v1 requirements: 30 total
- Mapped to phases: 30
- Unmapped: 0

---
*Requirements defined: 2026-03-16*
*Last updated: 2026-03-16 after roadmap creation*
