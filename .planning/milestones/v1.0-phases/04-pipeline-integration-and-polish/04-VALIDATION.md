---
phase: 4
slug: pipeline-integration-and-polish
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (existing) |
| **Config file** | Typeness.xcodeproj test target TypenessTests |
| **Quick run command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/PipelineIntegrationTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/PipelineIntegrationTests 2>&1 | tail -20`
- **After every plan wave:** Run `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 | tail -40`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 0 | UI-02 | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testMenuBarIconNames` | ❌ W0 | ⬜ pending |
| 04-01-02 | 01 | 0 | STT-04 | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testLatencyPropertySet` | ❌ W0 | ⬜ pending |
| 04-01-03 | 01 | 0 | DEBUG-01 | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testDebugModeTogglePersists` | ❌ W0 | ⬜ pending |
| 04-01-04 | 01 | 0 | DEBUG-02 | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testDebugArchiverCreatesFiles` | ❌ W0 | ⬜ pending |
| 04-01-05 | 01 | 0 | DEBUG-03 | unit | Share with DEBUG-01 test | ❌ W0 | ⬜ pending |
| 04-01-06 | 01 | 0 | DEBUG-04 | unit/manual | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testConfirmModeSetsPendingTranscription` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/TypenessTests/PipelineIntegrationTests.swift` — stubs for UI-02, STT-04, DEBUG-01, DEBUG-02, DEBUG-03, DEBUG-04
- [ ] `Typeness/Core/DebugArchiver.swift` — minimal placeholder for build
- [ ] `Typeness/Core/AppState.swift` updates: add `.processing` to `RecordingState`, add `lastTranscriptionLatencyMs`, `pendingTranscription`, `lastError`, `menuBarIconName`

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Hotkey starts/stops recording with icon feedback | UI-02 | Requires system hotkey and menu bar interaction | Press hotkey, verify icon changes; release, verify processing icon; wait for text insertion, verify idle icon |
| Confirm-before-insert shows review sheet | DEBUG-04 | Requires SwiftUI sheet interaction | Enable confirm mode in settings, transcribe, verify sheet appears with text, confirm/cancel |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
