---
phase: 01-foundation
verified: 2026-03-16T15:30:00Z
status: passed
score: 11/11 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 10/11
  gaps_closed:
    - "User can configure hotkey bindings in settings (HOTKEY-03)"
  gaps_remaining: []
  regressions: []
---

# Phase 1: Foundation Verification Report

**Phase Goal:** Users can launch a functional menu bar app that persists their settings, requests required permissions, responds to global hotkeys, and downloads AI models in the background on first launch.
**Verified:** 2026-03-16T15:30:00Z
**Status:** passed
**Re-verification:** Yes — after gap closure (plan 01-04 closed HOTKEY-03)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | App launches in the menu bar with no Dock icon | VERIFIED | `TypenessApp.swift`: `MenuBarExtra` + `LSUIElement=true` in `Info.plist`; `menuBarExtraStyle(.window)` |
| 2 | Settings window opens from the menu bar popover button | VERIFIED | `StatusItemView.swift` L34-38: `setActivationPolicy(.regular)` + `openSettings()` |
| 3 | Launch at Login toggle reads/writes SMAppService.mainApp.status | VERIFIED | `SettingsView.swift` L29-42: get checks `.enabled`, set calls `register()`/`unregister()` |
| 4 | Settings persist across app restart via UserDefaults | VERIFIED | `SettingsStore.swift`: 7 `@AppStorage` properties; hotkey codes, modifiers, flags, onboarding state |
| 5 | Toggle hotkey (Shift+Option+Space) fires globally and posts notification | VERIFIED | `HotkeyMonitor.swift` L109-111: `matchesToggle` check → `hotkeyToggleFired` → `return nil` |
| 6 | PTT hotkey (Option+Space) fires on keyDown and keyUp | VERIFIED | `HotkeyMonitor.swift` L113-115, L118-121: `hotkeyPTTDown` / `hotkeyPTTUp` posted and suppressed |
| 7 | Hotkey events are suppressed — no spurious characters reach active app | VERIFIED | `HotkeyMonitor.swift` L111, 115, 121: `return nil` for all matched hotkeys; tap at `.cghidEventTap` / `.headInsertEventTap` |
| 8 | CGEventTap re-enables itself after macOS watchdog timeout | VERIFIED | `HotkeyMonitor.swift` L98-103: `type == .tapDisabledByTimeout` → `CGEvent.tapEnable(tap: tap, enable: true)` |
| 9 | First launch shows onboarding requesting Accessibility permission | VERIFIED | `OnboardingView.swift`: `AXIsProcessTrustedWithOptions` with prompt; `TypenessApp.swift` shows sheet when `!settingsStore.hasShownOnboarding` |
| 10 | Every launch checks AXIsProcessTrusted and surfaces warning if revoked | VERIFIED | `AppState.swift` L18-23: `checkAccessibilityOnStartup()` → `.granted` or `.revoked`; called from `setupApp()` |
| 11 | User can configure hotkey bindings in settings | VERIFIED | `SettingsView.swift` L46-47: two `HotkeyRecorderRow` instances replace former static labels; `HotkeyRecorderView.swift` bridges `KeyboardShortcuts.Recorder` to `SettingsStore` via `syncToSettingsStore`; `HotkeyMonitor.loadSettings(from:)` reads updated values |
| 12 | Model download progress visible in menu bar on first launch | VERIFIED | `StatusItemView.swift` L13-16: `ProgressView(value: progress)` when `appState.modelDownloadProgress != nil`; `ModelManager` updates via `DownloadProgressDelegate` |
| 13 | ModelManager downloads to ~/Library/Application Support/Typeness/Models/ | VERIFIED | `ModelManager.swift` L9-11: `applicationSupportDirectory` + `"Typeness/Models"` path component |

**Score:** 13/13 truths verified (11/11 phase must-haves; model download and download path are additional truths from plan 03)

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Typeness/App/TypenessApp.swift` | @main entry with MenuBarExtra + Settings scene + HotkeyMonitor wiring | VERIFIED | All three scenes present; `setupApp()` calls `loadSettings`/`start`; `.task` for model download |
| `Typeness/App/SettingsStore.swift` | UserDefaults-backed settings | VERIFIED | 7 `@AppStorage` properties including hotkey key codes and modifiers |
| `Typeness/Core/AppState.swift` | Observable app state | VERIFIED | `@Observable final class`; all expected properties; `checkAccessibilityOnStartup()` |
| `Typeness/UI/SettingsView.swift` | Settings window with launch-at-login toggle and interactive hotkey recorder | VERIFIED | SMAppService toggle; `HotkeyRecorderRow` for both hotkeys; permission status display |
| `Typeness/UI/HotkeyRecorderView.swift` | SwiftUI bridge from KeyboardShortcuts.Recorder to SettingsStore | VERIFIED | Exists (44 lines); `KeyboardShortcuts.Name` extensions for `.toggleMode` and `.pushToTalk` with correct defaults; `syncToSettingsStore` writes keyCode + CGEventFlags-converted modifiers to `SettingsStore` |
| `Package.swift` | KeyboardShortcuts SPM dependency | VERIFIED | `.package(url: "https://github.com/sindresorhus/KeyboardShortcuts", .upToNextMinor(from: "1.15.0"))`; target dependency wired; `HotkeyRecorderView.swift` in sources list |
| `Typeness/Info.plist` | LSUIElement flag | VERIFIED | `<key>LSUIElement</key>` present |
| `Typeness/Input/HotkeyMonitor.swift` | CGEventTap-based global hotkey monitor + loadSettings | VERIFIED | `CGEvent.tapCreate`; `tapDisabledByTimeout` re-enable; `return nil` suppression; `loadSettings(from:)` L65-70 |
| `Typeness/UI/OnboardingView.swift` | First-launch permission onboarding | VERIFIED | `AXIsProcessTrustedWithOptions` with prompt; polling timer; `hasShownOnboarding` gate |
| `Typeness/Core/ModelManager.swift` | URLSession-based model download | VERIFIED | `actor ModelManager`; `URLSessionDownloadDelegate`; progress → `AppState.modelDownloadProgress`; correct path |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `StatusItemView.swift` | Settings window | `setActivationPolicy(.regular)` + `openSettings()` | WIRED | L34-38 |
| `SettingsView.swift` | SMAppService | `SMAppService.mainApp.status` | WIRED | L29, L33, L35 |
| `HotkeyRecorderView.swift` | `SettingsStore` | `syncToSettingsStore` → writes `toggleHotkeyKeyCode`/`pttHotkeyKeyCode` and modifiers | WIRED | L36-42 — `settingsStore.toggleHotkeyKeyCode = keyCode` and `settingsStore.pttHotkeyKeyCode = keyCode` confirmed |
| `HotkeyMonitor.swift` | `SettingsStore` | `loadSettings(from:)` reads all 4 properties | WIRED | L65-70: reads `toggleHotkeyKeyCode`, `toggleHotkeyModifiers`, `pttHotkeyKeyCode`, `pttHotkeyModifiers` |
| `HotkeyMonitor.swift` | `AppState.swift` | `NotificationCenter.default.post` | WIRED | L110, 114, 120 — consumers subscribe; dispatch bridge present |
| `HotkeyMonitor.swift` | CGEventTap re-enable | `tapDisabledByTimeout` handler | WIRED | L98-103 |
| `OnboardingView.swift` | `AXIsProcessTrusted` | `AXIsProcessTrustedWithOptions` + polling | WIRED | L33-34, L48-52 |
| `ModelManager.swift` | `AppState.modelDownloadProgress` | `DownloadProgressDelegate` callback → `MainActor.run` | WIRED | L49-52, L59-62 |
| `TypenessApp.swift` | `HotkeyMonitor.start()` | `setupApp()` / `startHotkeyMonitor()` after AX check | WIRED | L48-66 |
| `TypenessApp.swift` | `ModelManager.downloadWhisperModelIfNeeded()` | `.task` modifier on hidden window | WIRED | L16-22 |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| UI-01 | 01-01 | App runs as menu bar app (LSUIElement) with no dock icon | SATISFIED | `MenuBarExtra` + `LSUIElement=true` in plist |
| UI-03 | 01-01 | App displays SwiftUI settings window accessible from menu bar | SATISFIED | `Settings` scene + `openSettings()` wired in `StatusItemView` |
| UI-04 | 01-03 | Menu bar shows model loading progress on first launch | SATISFIED | `ProgressView` in `StatusItemView` driven by `modelDownloadProgress` |
| SYS-01 | 01-01 | App can auto-start at login via SMAppService | SATISFIED | `SMAppService.mainApp.register()` in `SettingsView` |
| SYS-02 | 01-02 | App presents permission onboarding for Accessibility on first launch | SATISFIED | `OnboardingView` shown when `!settingsStore.hasShownOnboarding` |
| SYS-03 | 01-02 | App checks Accessibility trust status on startup and prompts if revoked | SATISFIED | `checkAccessibilityOnStartup()` called in `setupApp()`; sets `.revoked` status |
| HOTKEY-01 | 01-02 | User can activate voice input via toggle mode (Shift+Option+Space) | SATISFIED | `hotkeyToggleFired` notification posted and event suppressed |
| HOTKEY-02 | 01-02 | User can activate voice input via push-to-talk (Option+Space) | SATISFIED | `hotkeyPTTDown`/`hotkeyPTTUp` posted and events suppressed |
| HOTKEY-03 | 01-02, 01-04 | User can configure hotkey bindings in settings | SATISFIED | `SettingsView` L46-47: two `HotkeyRecorderRow` instances; `HotkeyRecorderView.swift` bridges `KeyboardShortcuts.Recorder(for:onChange:)` to `SettingsStore`; `Package.swift` includes KeyboardShortcuts 1.15.0; no static labels remain |
| HOTKEY-04 | 01-02 | Hotkeys work globally across all applications | SATISFIED | CGEventTap at `.cghidEventTap` / `.headInsertEventTap` — system-level intercept before any app |
| HOTKEY-05 | 01-02 | Hotkey events are suppressed (not passed to active app) | SATISFIED | `return nil` from callback for all matched events |

**Orphaned requirements:** None. All 11 requirement IDs from plans are mapped and accounted for.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Typeness/Core/ModelManager.swift` | 44 | `// Placeholder URL — will be replaced with actual HuggingFace URL in Phase 2` | Info | Download URL is a real HuggingFace URL despite the comment; acceptable for Phase 1 |
| `Typeness/App/TypenessApp.swift` | 21 | `try?` silently swallows download errors | Info | Network errors during model download are silently ignored; acceptable for Phase 1 scaffold |

No blockers or warnings found. No regressions introduced by plan 01-04.

---

## Human Verification Required

### 1. Menu bar app launches with no Dock icon

**Test:** Build and launch Typeness.app on macOS 14+
**Expected:** App icon appears in menu bar; no icon in Dock; no app window appears
**Why human:** Runtime behavior — `LSUIElement` + `MenuBarExtra` interaction requires actual launch

### 2. Global hotkeys work across all applications

**Test:** Launch app, grant Accessibility permission, then switch to a text editor and press Shift+Option+Space and Option+Space
**Expected:** No character inserted in text editor; hotkey events are consumed by Typeness
**Why human:** CGEventTap behavior requires actual runtime with Accessibility grant

### 3. CGEventTap survives 20+ consecutive activations

**Test:** Press Shift+Option+Space rapidly 25+ times over 30 seconds
**Expected:** All activations fire; tap does not become disabled
**Why human:** `tapDisabledByTimeout` watchdog is triggered by rapid events — requires real input simulation

### 4. Onboarding sheet appears on first launch

**Test:** Delete `UserDefaults` key `hasShownOnboarding` (or use a fresh app install), launch the app
**Expected:** OnboardingView sheet appears explaining Accessibility permission
**Why human:** Sheet presentation tied to hidden window `.onAppear` — requires runtime observation

### 5. Model download progress visible in menu bar

**Test:** Delete `~/Library/Application Support/Typeness/Models/ggml-large-v3-turbo.bin` if it exists, launch app, click menu bar icon
**Expected:** Linear progress bar and "Downloading models... X%" text visible in popover
**Why human:** Requires network connection and actual download initiation

### 6. Hotkey recorder control in Settings window

**Test:** Open Settings, navigate to Hotkeys section, click on the Toggle Mode recorder field
**Expected:** Field activates and waits for a key combination; pressing a new shortcut updates the field and persists to UserDefaults
**Why human:** KeyboardShortcuts.Recorder UI interaction and UserDefaults write require runtime observation; cannot verify key capture from static analysis

---

## Re-verification Summary

The single gap from the initial verification — **HOTKEY-03** ("User can configure hotkey bindings in settings") — is now closed.

Evidence of closure:

1. `Typeness/UI/HotkeyRecorderView.swift` exists (44 lines, substantive) — defines `KeyboardShortcuts.Name` extensions for `.toggleMode` (default: Shift+Option+Space) and `.pushToTalk` (default: Option+Space), and `HotkeyRecorderRow` view that hosts `KeyboardShortcuts.Recorder(for: name, onChange:)` with a `syncToSettingsStore` handler that converts `NSEvent.ModifierFlags` to `CGEventFlags` raw values and writes to `SettingsStore.toggleHotkeyKeyCode` / `pttHotkeyKeyCode` / `toggleHotkeyModifiers` / `pttHotkeyModifiers`.

2. `Typeness/UI/SettingsView.swift` no longer contains `Text("⇧⌥Space")` or `Text("⌥Space")`. The Hotkeys section (L45-48) now uses two `HotkeyRecorderRow` instances.

3. `Package.swift` includes `KeyboardShortcuts 1.15.0` as an SPM dependency and `HotkeyRecorderView.swift` in the target sources list.

4. `Typeness/Input/HotkeyMonitor.swift` has `func loadSettings(from store: SettingsStore)` at L65-70, reading all four SettingsStore hotkey properties, completing the round-trip from UI recorder through persistence to the CGEventTap backend.

No regressions were detected in the previously-verified truths. All 11 phase requirements are now SATISFIED.

---

_Verified: 2026-03-16T15:30:00Z_
_Verifier: Claude (gsd-verifier)_
