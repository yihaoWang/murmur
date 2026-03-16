---
phase: 2
slug: audio-capture-and-transcription
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in with Xcode) |
| **Config file** | none — Wave 0 creates test target |
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
| 02-01-01 | 01 | 1 | AUDIO-01 | unit | `xcodebuild test -only-testing TypenessTests/AudioCaptureTests` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 1 | AUDIO-02 | manual | N/A — permission dialog | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 1 | AUDIO-03 | unit | `xcodebuild test -only-testing TypenessTests/AudioCaptureTests` | ❌ W0 | ⬜ pending |
| 02-02-01 | 02 | 2 | STT-01 | integration | `xcodebuild test -only-testing TypenessTests/WhisperBridgeTests` | ❌ W0 | ⬜ pending |
| 02-02-02 | 02 | 2 | STT-02 | manual | Model download with progress | ❌ W0 | ⬜ pending |
| 02-02-03 | 02 | 2 | STT-03 | unit | `xcodebuild test -only-testing TypenessTests/VADTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `TypenessTests/` test target — create if not exists in Xcode project
- [ ] `TypenessTests/AudioCaptureTests.swift` — stubs for AUDIO-01, AUDIO-03
- [ ] `TypenessTests/WhisperBridgeTests.swift` — stubs for STT-01
- [ ] `TypenessTests/VADTests.swift` — stubs for STT-03

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

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
