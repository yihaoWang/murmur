---
phase: 3
slug: llm-post-processing-and-text-insertion
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (built-in with Xcode) |
| **Config file** | TypenessTests target from Phase 2 Wave 0 |
| **Quick run command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests 2>&1 \| tail -20` |
| **Full suite command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 \| tail -40` |
| **Estimated runtime** | ~20 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick test command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 20 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-00-01 | 00 | 0 | — | scaffold | `swift test --list-tests` | ❌ W0 | ⬜ pending |
| 03-01-01 | 01 | 1 | LLM-01 | unit | `xcodebuild test -only-testing TypenessTests/LLMProcessorTests` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | LLM-02 | unit | `xcodebuild test -only-testing TypenessTests/LLMProcessorTests` | ❌ W0 | ⬜ pending |
| 03-01-03 | 01 | 1 | LLM-03 | manual | Model download with progress | N/A | ⬜ pending |
| 03-02-01 | 02 | 1 | INSERT-01 | unit | `xcodebuild test -only-testing TypenessTests/TextInserterTests` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 1 | INSERT-02, INSERT-03 | unit | `xcodebuild test -only-testing TypenessTests/TextInserterTests` | ❌ W0 | ⬜ pending |
| 03-02-03 | 02 | 1 | INSERT-04 | unit | `xcodebuild test -only-testing TypenessTests/TextInserterTests` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `Tests/TypenessTests/LLMProcessorTests.swift` — stubs for LLM-01, LLM-02
- [ ] `Tests/TypenessTests/TextInserterTests.swift` — stubs for INSERT-01, INSERT-02, INSERT-03, INSERT-04

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Model download with progress | LLM-03 | Requires network + first-launch state | Delete model cache, launch app, verify progress indicator |
| AX insertion in TextEdit | INSERT-01 | Requires running app + AX permission | Open TextEdit, place cursor, trigger insertion, verify text appears |
| Clipboard fallback in VS Code | INSERT-02 | Requires Electron app + AX failure detection | Open VS Code, place cursor, trigger insertion, verify paste fallback |
| Clipboard restore after paste | INSERT-03 | Requires clipboard state observation | Copy text to clipboard, trigger insertion, verify original clipboard restored |
| TransientType marker | INSERT-04 | Requires clipboard manager observation | Install Maccy, trigger insertion, verify paste not captured in history |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 20s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
