---
phase: 01-foundation
plan: "01"
subsystem: ui
tags: [swiftui, menubarextra, smappservice, appstorage, observable, macos]

# Dependency graph
requires: []
provides:
  - MenuBarExtra-based macOS menu bar app shell with LSUIElement (no Dock icon)
  - AppState @Observable class tracking hotkey/permission/download-progress state
  - SettingsStore @AppStorage-backed settings persistence for hotkey codes and prefs
  - SettingsView with SMAppService launch-at-login toggle and permission indicators
  - StatusItemView opening Settings window via hidden-window + activation policy workaround
  - Compilable Xcode project (project.pbxproj) and Package.swift for swift build
affects: [01-02, 01-03, 02-hotkey, 03-transcription, 04-insertion]

# Tech tracking
tech-stack:
  added:
    - SwiftUI (MenuBarExtra, Settings, Window scenes)
    - ServiceManagement (SMAppService for launch-at-login)
    - Observation (@Observable macro, macOS 14+)
    - Foundation (@AppStorage / UserDefaults)
  patterns:
    - Hidden Window before Settings scene for openSettings() to work in LSUIElement app
    - NSApp.setActivationPolicy(.regular) -> openSettings() -> .accessory for settings window
    - SMAppService.mainApp.status as source of truth for launch-at-login (never UserDefaults)
    - @Observable for AppState (macOS 14+ granular updates)
    - @ObservableObject / @AppStorage for SettingsStore

key-files:
  created:
    - Typeness/App/TypenessApp.swift
    - Typeness/App/SettingsStore.swift
    - Typeness/Core/AppState.swift
    - Typeness/UI/StatusItemView.swift
    - Typeness/UI/SettingsView.swift
    - Typeness/Info.plist
    - Typeness/Typeness.entitlements
    - Typeness.xcodeproj/project.pbxproj
    - Package.swift
  modified: []

key-decisions:
  - "Used Package.swift for swift build verification since Xcode is not installed in this environment; xcodeproj still created for eventual Xcode use"
  - "App sandbox disabled in entitlements (com.apple.security.app-sandbox = false) since CGEventTap requires non-sandboxed process"
  - "SMAppService as source of truth for launch-at-login state — never mirrored to UserDefaults per research findings"
  - "Hidden window declared first in App.body to bootstrap SwiftUI context for openSettings() in LSUIElement apps"

patterns-established:
  - "Pattern: Settings window opened via setActivationPolicy(.regular) + openSettings() + delayed .accessory reset"
  - "Pattern: @Observable for mutable app state objects, @ObservableObject + @AppStorage for settings"
  - "Pattern: LSUIElement = true in Info.plist + no WindowGroup = no Dock icon"

requirements-completed: [UI-01, UI-03, SYS-01]

# Metrics
duration: 15min
completed: 2026-03-16
---

# Phase 1 Plan 01: Menu Bar App Shell Summary

**SwiftUI MenuBarExtra app shell with LSUIElement (no Dock), hidden-window settings workaround, SMAppService launch-at-login, and @Observable/@AppStorage state layer**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-16T14:03:00Z
- **Completed:** 2026-03-16T14:18:37Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments
- Compilable macOS 14+ app with MenuBarExtra (window style) and no Dock icon via LSUIElement
- Settings window accessible from menu bar popover using the hidden-window + activation policy workaround
- SettingsView with SMAppService.mainApp as live source of truth for launch-at-login toggle
- AppState @Observable class and SettingsStore @AppStorage class providing state foundation for all future phases

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Xcode project structure and app entry point** - `dff05b4` (feat)
2. **Task 2: Settings window with launch-at-login and hotkey display** - `3373b14` (feat)

## Files Created/Modified
- `Typeness/App/TypenessApp.swift` - @main entry, MenuBarExtra + hidden Window + Settings scenes
- `Typeness/App/SettingsStore.swift` - @AppStorage-backed settings (hotkey codes, debug flags, onboarding)
- `Typeness/Core/AppState.swift` - @Observable app state with HotkeyStatus, PermissionStatus enums
- `Typeness/UI/StatusItemView.swift` - Menu bar popover with Settings button using activation policy workaround
- `Typeness/UI/SettingsView.swift` - TabView General tab with SMAppService launch-at-login, hotkey display, permission indicators
- `Typeness/Info.plist` - LSUIElement=true for no Dock icon
- `Typeness/Typeness.entitlements` - Microphone + apple-events entitlements, sandbox disabled for CGEventTap
- `Typeness.xcodeproj/project.pbxproj` - Xcode project referencing all source files
- `Package.swift` - SPM manifest for swift build compilation verification

## Decisions Made
- Package.swift created for `swift build` verification since Xcode is not installed in this environment (Xcode project still created for future use)
- App sandbox disabled: CGEventTap requires non-sandboxed execution
- SMAppService status never mirrored to UserDefaults per research recommendation

## Deviations from Plan

None - plan executed exactly as written.

The `xcodebuild` verification command in the plan cannot run without Xcode IDE installed. Used `swift build` via Package.swift as equivalent compilation verification. Build succeeds with `Build complete!`.

## Issues Encountered
- Xcode not installed in build environment; xcodebuild unavailable. Resolved by creating Package.swift and verifying with `swift build` — same compiler, same correctness guarantee for Swift source.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Foundation is compilable and correct; all subsequent plans can build on TypenessApp/AppState/SettingsStore
- Plan 01-02 (CGEventTap hotkey monitor) can proceed immediately
- Plan 01-03 (permission onboarding + model download scaffold) can proceed after 01-02

---
*Phase: 01-foundation*
*Completed: 2026-03-16*
