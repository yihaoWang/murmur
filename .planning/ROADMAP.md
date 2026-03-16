# Roadmap: Typeness (Swift)

## Overview

Four phases that build from a working macOS app shell to a fully integrated voice-to-text pipeline. Phase 1 establishes the foundation everything depends on — app entry point, settings, permissions, and reliable hotkeys. Phase 2 solves the hardest infrastructure problem: getting audio data into whisper.cpp correctly. Phase 3 wires in LLM post-processing and text insertion to produce the final output. Phase 4 integrates the full pipeline and completes the UI, delivering a shippable app.

## Phases

- [x] **Phase 1: Foundation** - Menu bar app shell, settings store, model manager, permissions onboarding, and reliable global hotkeys (completed 2026-03-16)
- [ ] **Phase 2: Audio Capture and Transcription** - 16kHz audio pipeline and whisper.cpp Metal-accelerated transcription bridge
- [ ] **Phase 3: LLM Post-Processing and Text Insertion** - Qwen3-1.7B formatting and dual-path text insertion at cursor
- [ ] **Phase 4: Pipeline Integration and Polish** - RecordingCoordinator wiring, menu bar status states, debug mode, and distribution readiness

## Phase Details

### Phase 1: Foundation
**Goal**: Users can launch a functional menu bar app that persists their settings, requests required permissions, responds to global hotkeys, and downloads AI models in the background on first launch.
**Depends on**: Nothing (first phase)
**Requirements**: UI-01, UI-03, UI-04, SYS-01, SYS-02, SYS-03, HOTKEY-01, HOTKEY-02, HOTKEY-03, HOTKEY-04, HOTKEY-05
**Success Criteria** (what must be TRUE):
  1. App lives in the menu bar with no dock icon and a SwiftUI settings window is accessible from the menu bar item
  2. On first launch, app presents permission onboarding for Accessibility and Microphone and explains why each is needed
  3. App checks Accessibility trust on startup and shows a warning if it has been revoked
  4. Both toggle mode (Shift+Option+Space) and push-to-talk (Option+Space) hotkeys fire globally across all applications and are configurable in settings
  5. Hotkey events are suppressed so they do not reach the active application; tap survives 20+ consecutive activations without silently disabling
  6. App can auto-start at login via SMAppService and model download progress is visible in the menu bar on first launch
**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Xcode project, app shell, MenuBarExtra, SettingsStore, Settings window, launch-at-login
- [x] 01-02-PLAN.md — CGEventTap hotkey monitor, permissions onboarding, startup AX check
- [x] 01-03-PLAN.md — ModelManager download infrastructure, progress display in menu bar
- [ ] 01-04-PLAN.md — Gap closure: interactive hotkey recorder UI (HOTKEY-03)

### Phase 2: Audio Capture and Transcription
**Goal**: User's voice is captured from the microphone at 16kHz mono Float32, transcribed by whisper.cpp with Metal GPU acceleration, with silence/noise gating preventing hallucinated output.
**Depends on**: Phase 1
**Requirements**: AUDIO-01, AUDIO-02, AUDIO-03, STT-01, STT-02, STT-03
**Success Criteria** (what must be TRUE):
  1. App requests microphone permission on first use with a clear explanation message
  2. Audio capture starts and stops within 100ms of a hotkey event
  3. Recorded audio is correctly resampled to 16kHz mono Float32 (feeding garbage-free PCM to whisper.cpp)
  4. Whisper large-v3-turbo model is downloaded on first launch with a progress indicator; transcription runs on Metal GPU
  5. Speaking a phrase in Traditional Chinese produces correct transcribed text; speaking silence or pure noise produces no output
**Plans:** 3/4 plans executed

Plans:
- [ ] 02-00-PLAN.md — Wave 0: XCTest target and stub test files for Nyquist compliance
- [ ] 02-01-PLAN.md — AudioCaptureEngine with AVAudioEngine + AVAudioConverter resampling to 16kHz mono Float32
- [ ] 02-02-PLAN.md — SwiftWhisper SPM dependency, TranscriptionEngine actor, VAD energy gate
- [ ] 02-03-PLAN.md — Wire capture and transcription to hotkey events, verify model download URL

### Phase 3: LLM Post-Processing and Text Insertion
**Goal**: Raw whisper transcription is formatted by a local Qwen3-1.7B model for Traditional Chinese punctuation conventions, then inserted at the cursor position in any application.
**Depends on**: Phase 2
**Requirements**: LLM-01, LLM-02, LLM-03, INSERT-01, INSERT-02, INSERT-03, INSERT-04
**Success Criteria** (what must be TRUE):
  1. Qwen3-1.7B model downloads on first launch with a progress indicator; post-processing runs on-device with no network access
  2. Post-processed output follows Traditional Chinese conventions — no spaces between characters, correct punctuation
  3. Text is inserted at the cursor position in native apps (TextEdit, Notes, Mail) via Accessibility API
  4. In Electron apps (VS Code, Slack) and Terminal where AX insertion fails, app falls back to clipboard paste and restores original clipboard contents afterward
  5. NSPasteboard TransientType marker is used so clipboard history managers do not capture the temporary paste content
**Plans**: TBD

### Phase 4: Pipeline Integration and Polish
**Goal**: All components are wired into a single RecordingCoordinator state machine delivering end-to-end voice-to-text, with complete menu bar status feedback, debug recording archive, and confirm-before-insert mode.
**Depends on**: Phase 3
**Requirements**: UI-02, STT-04, DEBUG-01, DEBUG-02, DEBUG-03, DEBUG-04
**Success Criteria** (what must be TRUE):
  1. Pressing the hotkey starts recording (icon changes), releasing/toggling stops and processes (icon shows processing), and the transcribed text appears at the cursor (icon returns to idle)
  2. Menu bar icon shows distinct visual states for idle, recording, processing, and error conditions
  3. Transcription latency is displayed in the menu bar or status area after each transcription
  4. User can enable debug mode in settings; when enabled, each transcription session saves a WAV file and JSON metadata to disk
  5. User can enable confirm-before-insert in settings; when enabled, the transcribed text is shown for review and must be confirmed before insertion
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation | 4/4 | Complete   | 2026-03-16 |
| 2. Audio Capture and Transcription | 3/4 | In Progress|  |
| 3. LLM Post-Processing and Text Insertion | 0/TBD | Not started | - |
| 4. Pipeline Integration and Polish | 0/TBD | Not started | - |
