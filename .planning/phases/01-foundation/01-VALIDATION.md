---
phase: 1
slug: foundation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (Xcode built-in) |
| **Config file** | None — Xcode test target configuration |
| **Quick run command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests` |
| **Full suite command** | `xcodebuild test -scheme Typeness -destination 'platform=macOS'` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `xcodebuild build -scheme Typeness -destination 'platform=macOS'`
- **After every plan wave:** Run `xcodebuild test -scheme Typeness -destination 'platform=macOS'`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Req ID | Behavior | Test Type | Automated Command | File Exists | Status |
|--------|----------|-----------|-------------------|-------------|--------|
| UI-01 | App launches with no Dock icon | smoke | Manual verify at launch | Manual-only | ⬜ pending |
| UI-03 | Settings window opens from menu bar | smoke | Manual verify click | Manual-only | ⬜ pending |
| UI-04 | Model download progress visible | unit | `TypenessTests/ModelManagerTests::testProgressReporting` | ❌ W0 | ⬜ pending |
| SYS-01 | SMAppService registers/unregisters | unit | `TypenessTests/SettingsStoreTests::testLaunchAtLoginToggle` | ❌ W0 | ⬜ pending |
| SYS-02 | Onboarding shown on first launch only | unit | `TypenessTests/OnboardingTests::testFirstLaunchFlag` | ❌ W0 | ⬜ pending |
| SYS-03 | Accessibility check runs at startup | unit | `TypenessTests/HotkeyMonitorTests::testAXTrustCheck` | ❌ W0 | ⬜ pending |
| HOTKEY-01 | Toggle hotkey fires globally | integration | Manual: 20 consecutive activations | Manual-only | ⬜ pending |
| HOTKEY-02 | PTT hotkey keyDown/keyUp pair fires | integration | Manual: hold + release test | Manual-only | ⬜ pending |
| HOTKEY-03 | Hotkey config persists to UserDefaults | unit | `TypenessTests/SettingsStoreTests::testHotkeyPersistence` | ❌ W0 | ⬜ pending |
| HOTKEY-04 | Hotkey fires in third-party app context | integration | Manual: switch app, test hotkey | Manual-only | ⬜ pending |
| HOTKEY-05 | Event suppressed (no pass to active app) | integration | Manual: type in TextEdit, verify no spurious chars | Manual-only | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `TypenessTests/HotkeyMonitorTests.swift` — covers SYS-03 (AX trust check)
- [ ] `TypenessTests/SettingsStoreTests.swift` — covers SYS-01 (SMAppService), HOTKEY-03 (persistence)
- [ ] `TypenessTests/ModelManagerTests.swift` — covers UI-04 (download progress)
- [ ] `TypenessTests/OnboardingTests.swift` — covers SYS-02 (first launch flag)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| No Dock icon | UI-01 | LSUIElement is Info.plist config | Launch app, verify no Dock icon appears |
| Settings window opens | UI-03 | Requires running app with menu bar | Click menu bar icon, click Settings, verify window appears |
| Toggle hotkey fires globally | HOTKEY-01 | CGEventTap requires Accessibility + running app | Press Shift+Option+Space in TextEdit, verify event fires |
| PTT hotkey fires | HOTKEY-02 | CGEventTap requires Accessibility + running app | Hold Option+Space, release, verify keyDown/keyUp events |
| Hotkey works cross-app | HOTKEY-04 | Requires multiple apps running | Switch to Safari, press hotkey, verify fires |
| Event suppression | HOTKEY-05 | Requires active text field | Type in TextEdit, press hotkey, verify no space character inserted |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
