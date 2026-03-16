---
phase: 01-foundation
plan: 02
subsystem: input
tags: [CGEventTap, hotkey, accessibility, onboarding, SwiftUI]

# Dependency graph
requires:
  - phase: 01-01
    provides: AppState, SettingsStore, TypenessApp scaffold
provides:
  - CGEventTap-based global hotkey monitor (HotkeyMonitor.swift)
  - Toggle hotkey (Shift+Option+Space) and PTT hotkey (Option+Space) support
  - tapDisabledByTimeout re-enable handling
  - Event suppression via return nil
  - NotificationCenter-based hotkey event dispatch
  - First-launch onboarding with Accessibility permission request and polling
  - Every-launch AXIsProcessTrusted check via AppState.checkAccessibilityOnStartup
affects: [02-whisper-integration, 03-llm-integration, 04-text-insertion]

# Tech tracking
tech-stack:
  added: [CoreGraphics CGEventTap, ApplicationServices AXIsProcessTrusted]
  patterns: [free C callback for CGEventTap, NotificationCenter for hotkey events, polling timer for permission grant detection]

key-files:
  created:
    - Typeness/Input/HotkeyMonitor.swift
    - Typeness/UI/OnboardingView.swift
  modified:
    - Typeness/Core/AppState.swift
    - Typeness/App/TypenessApp.swift
    - Package.swift

key-decisions:
  - "CGEvent.tapEnable(tap:enable:) used instead of deprecated CGEventTapEnable C function (Swift 3+ requirement)"
  - "tap property on HotkeyMonitor is internal (not private) so free C callback function can access it"
  - "kAXTrustedCheckOptionPrompt accessed via takeUnretainedValue() as String to resolve CFString to AnyHashable conversion error"

patterns-established:
  - "Free C function callback pattern for CGEventTap (closures not compatible with C function pointers)"
  - "tapDisabledByTimeout handled as first check in callback before any key processing"
  - "NotificationCenter.default.post for hotkey → consumer decoupling"
  - "1-second polling timer to detect accessibility grant in System Settings"

requirements-completed: [HOTKEY-01, HOTKEY-02, HOTKEY-03, HOTKEY-04, HOTKEY-05, SYS-02, SYS-03]

# Metrics
duration: 10min
completed: 2026-03-16
---

# Phase 1 Plan 02: CGEventTap Global Hotkeys and Accessibility Onboarding Summary

**CGEventTap-based global hotkey monitor with tapDisabledByTimeout re-enable, event suppression, and first-launch Accessibility permission onboarding**

## Performance

- **Duration:** ~10 min
- **Started:** 2026-03-16T14:20:00Z
- **Completed:** 2026-03-16T14:30:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- HotkeyMonitor registers CGEventTap at .cghidEventTap/.headInsertEventTap, handles watchdog timeout by re-enabling, suppresses matched events
- Toggle (Shift+Option+Space) posts .hotkeyToggleFired; PTT (Option+Space) posts .hotkeyPTTDown/.hotkeyPTTUp
- OnboardingView shows Accessibility explanation, opens System Settings with prompt, polls every 1s for grant
- TypenessApp starts HotkeyMonitor after permissions confirmed; checks AXIsProcessTrusted on every launch

## Task Commits

1. **Task 1: HotkeyMonitor with CGEventTap** - `9df529a` (feat)
2. **Task 2: First-launch onboarding and startup permission check** - `06174b6` (feat)

## Files Created/Modified
- `Typeness/Input/HotkeyMonitor.swift` - CGEventTap monitor with timeout re-enable and event suppression
- `Typeness/UI/OnboardingView.swift` - First-launch Accessibility permission onboarding with polling
- `Typeness/Core/AppState.swift` - Added checkAccessibilityOnStartup()
- `Typeness/App/TypenessApp.swift` - Added HotkeyMonitor start and onboarding presentation
- `Package.swift` - Added HotkeyMonitor.swift and OnboardingView.swift to sources

## Decisions Made
- Used `CGEvent.tapEnable(tap:enable:)` instead of deprecated `CGEventTapEnable` C function — Swift 3+ API requires this form
- Made `tap` property internal (not private) so the free C callback function can access it from file scope
- Used `kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String` to construct CFDictionary — resolves Unmanaged<CFString> key type error

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Replaced deprecated CGEventTapEnable with CGEvent.tapEnable(tap:enable:)**
- **Found during:** Task 1 (HotkeyMonitor build)
- **Issue:** Plan used `CGEventTapEnable(tap, true/false)` which was obsoleted in Swift 3; compiler error
- **Fix:** Replaced all calls with `CGEvent.tapEnable(tap: tap, enable: true/false)`
- **Files modified:** Typeness/Input/HotkeyMonitor.swift
- **Verification:** swift build succeeds
- **Committed in:** 9df529a (Task 1 commit)

**2. [Rule 1 - Bug] Fixed kAXTrustedCheckOptionPrompt CFDictionary key type**
- **Found during:** Task 2 (OnboardingView build)
- **Issue:** `[kAXTrustedCheckOptionPrompt: true] as CFDictionary` fails — kAXTrustedCheckOptionPrompt is Unmanaged<CFString>, not AnyHashable
- **Fix:** Used `kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String` as key
- **Files modified:** Typeness/UI/OnboardingView.swift
- **Verification:** swift build succeeds
- **Committed in:** 06174b6 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - deprecated/incompatible API usage)
**Impact on plan:** Both fixes required for compilation. No scope creep.

## Issues Encountered
- CGEventTap API changed in Swift 3+: `CGEventTapEnable` deprecated, free C function form not usable directly
- CFDictionary construction with CF constant keys requires explicit type bridging in Swift

## Next Phase Readiness
- Global hotkey system operational; Phase 2 (Whisper integration) can subscribe to NotificationCenter events
- AX permission check on every launch ensures hotkey won't silently fail after trust revocation

---
*Phase: 01-foundation*
*Completed: 2026-03-16*
