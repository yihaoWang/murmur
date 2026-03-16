---
phase: 2
slug: audio-capture-and-transcription
status: draft
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-16
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in with Xcode) |
| **Config file** | none — Wave 0 (plan 02-00) creates test target |
| **Quick run command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-00-01 | 00 | 0 | — | scaffold | `swift test --list-tests` | ✅ W0 | ⬜ pending |
| 02-01-01 | 01 | 1 | AUDIO-01 | unit | `xcodebuild test -only-testing TypenessTests/AudioCaptureTests` | ✅ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | AUDIO-02 | manual | N/A — permission dialog | N/A | ⬜ pending |
| 02-01-03 | 01 | 1 | AUDIO-03 | unit | `xcodebuild test -only-testing TypenessTests/AudioCaptureTests` | ✅ W0 | ⬜ pending |
| 02-02-01 | 02 | 1 | STT-01 | unit | `xcodebuild test -only-testing TypenessTests/WhisperBridgeTests` | ✅ W0 | ⬜ pending |
| 02-02-02 | 02 | 1 | STT-03 | unit | `xcodebuild test -only-testing TypenessTests/VADTests` | ✅ W0 | ⬜ pending |
| 02-03-01 | 03 | 2 | STT-02 | integration | `swift build` + manual checkpoint | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `TypenessTests/` test target — created by plan 02-00
- [x] `Tests/TypenessTests/AudioCaptureTests.swift` — stubs for AUDIO-01, AUDIO-03
- [x] `Tests/TypenessTests/WhisperBridgeTests.swift` — stubs for STT-01
- [x] `Tests/TypenessTests/VADTests.swift` — stubs for STT-03

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Microphone permission dialog | AUDIO-02 | System dialog requires user interaction | Reset privacy (`tccutil reset Microphone`), launch app, verify dialog appears with explanation |
| Model download with progress | STT-02 | Requires network + first-launch state | Delete model file, launch app, verify progress indicator in menu bar |
| Traditional Chinese transcription | STT-01 (partial) | Requires real microphone input | Record a TC phrase, verify output matches spoken content |
| Silence/noise produces no output | STT-03 (partial) | Requires real ambient conditions | Record silence/noise, verify empty or no transcription result |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved
