# Phase 1: Foundation - Research

**Researched:** 2026-03-16
**Domain:** macOS menu bar app shell, settings persistence, global hotkeys, permissions onboarding, model download scaffolding
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-01 | App runs as menu bar app (LSUIElement) with no dock icon | MenuBarExtra + LSUIElement pattern documented; `WindowGroup` omitted so no Dock entry appears |
| UI-03 | App displays SwiftUI settings window accessible from menu bar | Settings scene with workaround for MenuBarExtra context gap (hidden window + activation policy juggling) |
| UI-04 | Menu bar shows model loading progress on first launch | ModelManager downloads in background Task; AppState.modelDownloadProgress drives menu bar text/badge |
| SYS-01 | App can auto-start at login via SMAppService | SMAppService.mainApp.register() / .unregister(); status read from SMAppService, not UserDefaults |
| SYS-02 | App presents permission onboarding for Accessibility and Microphone on first launch | First-launch flag in UserDefaults; onboarding view checks both permissions sequentially |
| SYS-03 | App checks Accessibility trust status on startup and prompts if revoked | AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true]) called at every launch |
| HOTKEY-01 | User can activate voice input via toggle mode (default: Shift+Option+Space) | CGEventTap with event mask for keyDown; toggle state in RecordingCoordinator |
| HOTKEY-02 | User can activate voice input via push-to-talk (default: Option+Space) | CGEventTap onKeyDown / onKeyUp pair (NOT Carbon, due to macOS 15 Option-key bug) |
| HOTKEY-03 | User can configure hotkey bindings in settings | KeyboardShortcuts used for Settings UI only; raw CGEventTap used for actual monitoring |
| HOTKEY-04 | Hotkeys work globally across all applications | CGEventTap at kCGHIDEventTap level (HeadInsertEventTap) — fires before apps see the event |
| HOTKEY-05 | Hotkey events are suppressed (not passed to active app) | CGEventTap callback returns nil to consume the event; tap must re-enable on tapDisabledByTimeout |
</phase_requirements>

---

## Summary

Phase 1 builds the structural foundation that every subsequent phase depends on. No audio, transcription, or text insertion occurs in this phase — the deliverable is a compilable, launchable macOS menu bar app that: lives in the system tray (no Dock icon), persists settings to UserDefaults, presents permission onboarding for Accessibility and Microphone on first launch, registers a CGEventTap-based global hotkey that reliably fires across all applications without being consumed by the active app, supports auto-start at login via SMAppService, and downloads AI models in the background while showing progress in the menu bar.

The two technically dangerous components in this phase are the CGEventTap infrastructure and the Settings window. CGEventTap has a well-known silent-disable watchdog behavior that must be addressed from day one — if the callback does any real work, macOS disables the tap after a few activations with no visible error. The project already decided to use CGEventTap directly (not the KeyboardShortcuts library's Carbon RegisterEventHotKey backend) due to a confirmed macOS 15 bug where Option-key shortcuts stop working entirely when routed through Carbon. The Settings window in a menu bar app requires a non-obvious workaround because SwiftUI's `openSettings` environment action fails silently without proper activation policy context.

**Primary recommendation:** Implement CGEventTap directly with a timeout re-enable handler; use KeyboardShortcuts library only for the Settings UI hotkey recorder widget; open the Settings window via hidden-window + activation-policy pattern discovered in 2025.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI | macOS 14+ | Menu bar scene, settings window, onboarding UI | `MenuBarExtra` with `.menuBarExtraStyle(.window)` is the modern, boilerplate-free approach |
| CoreGraphics (CGEventTap) | system | Global hotkey interception, event suppression | Only mechanism to intercept AND suppress events before any app sees them; CGEventTap survives app focus changes |
| ServiceManagement (SMAppService) | macOS 13+ | Auto-start at login | Modern replacement for LaunchAgent plists; appears in System Settings > Login Items |
| ApplicationServices (AXIsProcessTrusted) | system | Accessibility permission check at startup | Required before registering CGEventTap; tap returns nil without this permission |
| Foundation (UserDefaults / @AppStorage) | system | Settings persistence | Zero-dependency; sufficient for the SettingsStore needs in this phase |
| URLSession | system | Model download with progress | `downloadTask` + `Progress` reporting; store in `~/Library/Application Support/Typeness/` |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| KeyboardShortcuts (sindresorhus) | 1.x | Hotkey recorder UI widget in Settings only | Use ONLY for the Settings UI text field that captures a hotkey binding; do NOT use for the actual event monitoring (uses Carbon backend with macOS 15 Option-key bug) |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| CGEventTap directly | KeyboardShortcuts full stack | KeyboardShortcuts uses Carbon RegisterEventHotKey backend — confirmed broken for Option-key shortcuts on macOS 15; CGEventTap avoids this entirely |
| SMAppService | LaunchAgent plist | LaunchAgent is for background daemons without UI; SMAppService.mainApp is correct for menu bar apps and shows in System Settings |
| @AppStorage / UserDefaults | Core Data | Core Data is massive overkill for settings key-value pairs |

**Installation:**
```bash
# In Xcode: File > Add Package Dependencies
# https://github.com/sindresorhus/KeyboardShortcuts (from: "1.0.0")
# No other third-party packages in Phase 1
```

---

## Architecture Patterns

### Recommended Project Structure

```
Typeness/
├── App/
│   ├── TypenessApp.swift          # @main, MenuBarExtra scene + hidden Settings window
│   ├── AppDelegate.swift          # NSApplicationDelegate (optional; lifecycle hooks)
│   └── SettingsStore.swift        # @AppStorage wrapper, single source of truth
│
├── UI/
│   ├── StatusItemView.swift        # Menu bar popover content (placeholder in Phase 1)
│   ├── SettingsView.swift          # Settings sheet: hotkeys, auto-start, permissions
│   ├── HotkeyRecorderView.swift    # KeyboardShortcuts recorder UI widget
│   ├── OnboardingView.swift        # First-launch permission request flow
│   └── ModelDownloadView.swift     # Download progress display (Phase 1: shell only)
│
├── Core/
│   ├── AppState.swift              # @Observable class: phase, progress, error, permissionStatus
│   └── ModelManager.swift          # URLSession download, progress, path resolution
│
└── Input/
    └── HotkeyMonitor.swift         # CGEventTap creation, timeout re-enable, event suppression
```

### Pattern 1: MenuBarExtra + LSUIElement (No Dock Icon)

**What:** Declare the app entry point with only `MenuBarExtra` and `Settings` scenes — no `WindowGroup`. Set `LSUIElement = YES` in Info.plist. This makes the app an "agent" with no Dock presence.

**When to use:** Every menu bar utility on macOS that should not appear in the Dock or App Switcher.

**Example:**
```swift
// Source: Apple Developer Docs — MenuBarExtra
@main
struct TypenessApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        // Hidden window provides SwiftUI context for openSettings — MUST be first
        Window("hidden", id: "hidden") {
            HiddenContextView(appState: appState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 0, height: 0)

        MenuBarExtra("Typeness", image: "MenuBarIcon") {
            StatusItemView(appState: appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(appState: appState)
        }
    }
}
```

**Info.plist** (required):
```xml
<key>LSUIElement</key>
<true/>
```

### Pattern 2: Opening Settings from Menu Bar (Critical Workaround)

**What:** SwiftUI's `@Environment(\.openSettings)` fails silently in menu bar apps without proper setup. The solution requires a hidden window declared before the Settings scene and activation policy juggling.

**Why it's non-obvious:** Menu bar apps run as `.accessory` activation policy (no Dock icon). Opening a Settings window requires temporarily switching to `.regular` policy so the window can receive focus, then switching back.

**When to use:** Any time a button or menu item in the MenuBarExtra popover should open the Settings window.

**Example:**
```swift
// Source: https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items
// In StatusItemView — the button that opens settings:
struct StatusItemView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings...") {
            NSApp.setActivationPolicy(.regular)
            openSettings()
            // Switch back after a brief delay so Dock icon doesn't linger
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
```

**The hidden window** (declared before Settings scene) bootstraps the SwiftUI render tree so `openSettings` has the context it needs. Without it, calling `openSettings()` silently does nothing.

### Pattern 3: CGEventTap with Timeout Re-Enable

**What:** Register a CGEventTap that intercepts global keyDown/keyUp events, suppresses the matched hotkeys (returns nil), and re-enables itself when macOS watchdog disables it.

**When to use:** All global hotkey monitoring in this project. Never use Carbon RegisterEventHotKey due to macOS 15 Option-key bug.

**Example:**
```swift
// Source: Apple Developer Docs — CGEventTap + tapDisabledByTimeout
final class HotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        guard AXIsProcessTrusted() else {
            // Check and prompt for Accessibility permission first
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)
            return
        }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) |
                   CGEventMask(1 << CGEventType.keyUp.rawValue) |
                   CGEventMask(1 << CGEventType.tapDisabledByTimeout.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,              // Before HID delivery
            place: .headInsertEventTap,        // Before any other tap
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: Unmanaged.passRetained(self).toOpaque()
        )
        guard let tap = eventTap else { return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEventTapEnable(tap, true)
    }
}

// The callback — must be a C function; do NO real work here
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passRetained(event) }
    let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon).takeUnretainedValue()

    // CRITICAL: handle timeout — re-enable the tap immediately
    if type == .tapDisabledByTimeout {
        if let tap = monitor.eventTap {
            CGEventTapEnable(tap, true)
        }
        return nil
    }

    // Check if this is a hotkey we care about — keyCode + modifiers only, no heavy logic
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    if monitor.matchesToggleHotkey(keyCode: keyCode, flags: flags) ||
       monitor.matchesPTTHotkey(keyCode: keyCode, flags: flags) {
        // Post notification — the ONLY work done here
        NotificationCenter.default.post(name: .hotkeyFired, object: HotkeyEvent(type: type))
        return nil  // Suppress event — do NOT pass to active app
    }

    return Unmanaged.passRetained(event)
}
```

**Key constraints on the callback:**
- Must complete in under 1ms
- No Swift async calls, no locks, no I/O
- Must be `@convention(c)` or a free function
- Must handle `.tapDisabledByTimeout` and call `CGEventTapEnable(tap, true)` immediately

### Pattern 4: SMAppService Login Item

**What:** Register or unregister the main app as a login item using `SMAppService.mainApp`. Read status from the service rather than storing locally.

**When to use:** Settings toggle for "Launch at Login".

**Example:**
```swift
// Source: Apple Developer Docs — SMAppService
import ServiceManagement

extension SettingsStore {
    var launchAtLoginEnabled: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Surface error in AppState
            }
        }
    }
}
```

**Important:** Do not mirror the status into UserDefaults. Always read from `SMAppService.mainApp.status` to reflect what the user may have changed in System Settings.

### Pattern 5: First-Launch Permissions Onboarding

**What:** On first launch, present a modal onboarding view explaining each required permission before requesting it, then request them in sequence. Check Accessibility trust at every subsequent launch.

**When to use:** Accessibility (required for text insertion AND CGEventTap registration) and Microphone (required for audio capture in Phase 2).

**Example:**
```swift
// Startup check (every launch):
func checkPermissionsOnStartup() {
    if !AXIsProcessTrusted() {
        // Show warning in menu bar — do not auto-prompt here
        appState.accessibilityStatus = .revoked
    }
}

// First-launch onboarding:
func requestAccessibilityPermission() {
    let options = [kAXTrustedCheckOptionPrompt: true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)
    // Note: this call opens System Settings and returns immediately
    // App must poll or observe trust status changes
}
```

**Polling pattern** (since AX permission grant is out-of-process):
```swift
// Poll every 1 second while onboarding is shown
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
    if AXIsProcessTrusted() {
        timer.invalidate()
        appState.accessibilityStatus = .granted
    }
}
```

### Anti-Patterns to Avoid

- **Putting work in the CGEventTap callback:** Any I/O, async bridging, or lock contention kills the callback deadline; macOS watchdog disables the tap silently after a few fires.
- **Using KeyboardShortcuts library for event monitoring:** Its Carbon backend breaks Option-key shortcuts on macOS 15. Use it for the recorder UI widget only.
- **Calling `openSettings()` without the hidden window + activation policy pattern:** Silently fails in LSUIElement apps; no error is surfaced.
- **Storing launch-at-login state in UserDefaults:** User can toggle login items in System Settings; app state will diverge. Always read `SMAppService.mainApp.status`.
- **Lazy-loading models (deferring download to first use):** Models must begin downloading at launch; hotkey should be disabled until models are ready.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Hotkey recorder UI | Custom NSEvent-capturing text field | `KeyboardShortcuts.Recorder` SwiftUI view | Handles all keyboard capture edge cases, modifier-only shortcuts, conflict detection |
| Login item management | LaunchAgent plist templating | `SMAppService.mainApp` | LaunchAgent path resolution breaks on update/reinstall; SMAppService handles all edge cases |
| Model download with resume | Custom URLSession download manager | `URLSession.downloadTask` + `Progress` | downloadTask handles network interruption, disk space, background transfers automatically |

**Key insight:** The hotkey recorder UI and the actual hotkey interception are two separate problems. KeyboardShortcuts solves the UI perfectly; CGEventTap solves the monitoring correctly. Use each for its strength.

---

## Common Pitfalls

### Pitfall 1: CGEventTap Silently Disabled by Watchdog

**What goes wrong:** After a few hotkey presses, the tap stops firing with no visible error. App restarts restore the hotkey but it fails again within minutes.

**Why it happens:** The tap callback exceeded macOS's processing deadline. This triggers `kCGEventTapDisabledByTimeout`. If the callback doesn't handle this event and re-enable the tap, it stays disabled forever.

**How to avoid:** Handle `type == .tapDisabledByTimeout` in the callback as the very first check. Call `CGEventTapEnable(tap, true)` immediately. Keep all other callback logic under 1ms (flag set, notification post — nothing else).

**Warning signs:** Hotkey works at launch, stops after a few transcriptions, resumes after app restart.

### Pitfall 2: Option-Key Hotkeys Silent on macOS 15 via Carbon

**What goes wrong:** Hotkeys using Option or Option+Shift as the sole modifier do not fire on macOS 15 when registered through `RegisterEventHotKey` (Carbon API). This is a confirmed Apple bug reported via Feedback Assistant.

**Why it happens:** macOS 15 changed how the Carbon event system handles Option-modified keys. Apple has not fixed this as of early 2026.

**How to avoid:** Use CGEventTap directly. Never use any library that routes through Carbon for actual monitoring (KeyboardShortcuts' monitoring backend uses Carbon). Use KeyboardShortcuts only for the recorder UI widget.

**Warning signs:** Hotkeys work on macOS 14 but silently fail on macOS 15 for all Option-combination bindings.

### Pitfall 3: openSettings Silently Fails in Menu Bar Apps

**What goes wrong:** Calling `@Environment(\.openSettings)` from a MenuBarExtra button does nothing. No error, no window.

**Why it happens:** LSUIElement apps run as `.accessory` activation policy. `openSettings` requires a window context that only exists when the app temporarily runs as `.regular`. The hidden window trick bootstraps this context, but the hidden window must be declared before the `Settings` scene in the `body`.

**How to avoid:** Declare a zero-size hidden `Window` scene as the first scene in `TypenessApp.body`. When opening settings, call `NSApp.setActivationPolicy(.regular)` first, then `openSettings()`, then switch back to `.accessory` after a short delay.

**Warning signs:** Settings button in popover does nothing; no crash, no log output.

### Pitfall 4: Accessibility Permission Revoked on Each Xcode Rebuild

**What goes wrong:** After every build, `AXIsProcessTrusted()` returns `false` even though System Settings shows the app as enabled. CGEventTap registration silently returns nil. Hotkeys do nothing.

**Why it happens:** TCC ties permission grants to the code signature hash. Debug builds from different signing configurations produce different hashes, invalidating the existing grant.

**How to avoid:** Always call `AXIsProcessTrusted()` at startup and surface the result in the UI immediately. During development, use `tccutil reset Accessibility com.typeness.app` to reset and re-grant cleanly rather than relying on stale grants.

**Warning signs:** Hotkeys work after fresh permission grant, fail silently after rebuild without any user action.

### Pitfall 5: SMAppService Status Diverges from UserDefaults

**What goes wrong:** App shows "Launch at Login: ON" in settings, but the user removed the login item from System Settings manually. App never knows.

**Why it happens:** Storing login-item state in UserDefaults creates a local copy that can diverge from the actual system state.

**How to avoid:** Always read `SMAppService.mainApp.status` as the source of truth. Compute the toggle's current state at view render time from the service, not from UserDefaults.

---

## Code Examples

### CGEventTap Registration with Permission Guard
```swift
// Source: Apple Developer Docs — CGEventTap
// HotkeyMonitor.swift

import CoreGraphics
import ApplicationServices

final class HotkeyMonitor {
    private var tap: CFMachPort?

    func start() throws {
        guard AXIsProcessTrusted() else {
            throw HotkeyError.accessibilityNotGranted
        }

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: rawCallback,
            userInfo: Unmanaged.passRetained(self).toOpaque()
        ) else {
            throw HotkeyError.tapCreationFailed
        }
        self.tap = tap

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEventTapEnable(tap, true)
    }
}
```

### AppState with @Observable (macOS 14+)
```swift
// Source: Apple Developer Docs — Observation framework
@Observable final class AppState {
    var hotkeyStatus: HotkeyStatus = .unregistered
    var accessibilityStatus: PermissionStatus = .unknown
    var microphoneStatus: PermissionStatus = .unknown
    var modelDownloadProgress: Double? = nil  // nil = not downloading
    var isFirstLaunch: Bool = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

    enum HotkeyStatus { case unregistered, active, disabled }
    enum PermissionStatus { case unknown, granted, denied, revoked }
}
```

### SettingsStore with @AppStorage
```swift
// Source: Apple Developer Docs — AppStorage
final class SettingsStore: ObservableObject {
    @AppStorage("toggleHotkeyKeyCode") var toggleHotkeyKeyCode: Int = 49    // Space
    @AppStorage("toggleHotkeyModifiers") var toggleHotkeyModifiers: Int = 786432  // Shift+Option
    @AppStorage("pttHotkeyKeyCode") var pttHotkeyKeyCode: Int = 49           // Space
    @AppStorage("pttHotkeyModifiers") var pttHotkeyModifiers: Int = 524288   // Option
    @AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false
    @AppStorage("confirmBeforeInsert") var confirmBeforeInsert: Bool = false
    @AppStorage("hasShownOnboarding") var hasShownOnboarding: Bool = false
}
```

### Model Download with Progress
```swift
// Source: Apple Developer Docs — URLSession downloadTask
actor ModelManager {
    private(set) var whisperModelURL: URL?
    private(set) var downloadProgress: Double = 0.0

    func downloadWhisperModel() async throws {
        let remoteURL = URL(string: "https://huggingface.co/.../ggml-large-v3-turbo.bin")!
        let destination = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Typeness/Models/ggml-large-v3-turbo.bin")

        for try await progress in URLSession.shared.download(from: remoteURL) {
            self.downloadProgress = progress.fractionCompleted
        }
        whisperModelURL = destination
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| LaunchAgent plist for login items | `SMAppService.mainApp` | macOS 13 (2022) | Login items now appear in System Settings; user can manage without hacking plists |
| `SMLoginItemSetEnabled` | `SMAppService.mainApp` | macOS 13 (2022) | Old API deprecated; new API works without embedded helper bundle |
| Carbon `RegisterEventHotKey` | CGEventTap directly | macOS 15 broke Carbon Option-key shortcuts (2024) | CGEventTap is the only reliable path for Option-modifier hotkeys on macOS 15+ |
| `ObservableObject` + `@Published` | `@Observable` macro | macOS 14 / Swift 5.9 (2023) | Eliminates boilerplate; more granular view updates; requires macOS 14+ |
| Manual `NSStatusItem` + `NSPopover` | `MenuBarExtra` SwiftUI scene | macOS 13 (2022) | Much less boilerplate; SwiftUI-native; still has Settings window gaps requiring workarounds |

**Deprecated/outdated:**
- `SMLoginItemSetEnabled`: Deprecated, shows nothing in System Settings
- Carbon `RegisterEventHotKey`: Broken for Option-modifier keys on macOS 15
- `ObservableObject` / `@Published` for new code: Still works but `@Observable` is preferred on macOS 14+

---

## Open Questions

1. **KeyboardShortcuts recorder UI compatibility with CGEventTap monitoring**
   - What we know: KeyboardShortcuts uses Carbon for its monitoring backend; we use it for UI only
   - What's unclear: Does the KeyboardShortcuts recorder UI (SwiftUI widget) interfere with our CGEventTap-based monitoring when both are active simultaneously?
   - Recommendation: Initialize HotkeyMonitor before KeyboardShortcuts registers any recorder, and test that both can coexist without conflict

2. **CGEventTap behavior when Accessibility permission is revoked mid-session**
   - What we know: CGEventTap returns nil on tap creation without Accessibility; on permission revocation the tap becomes inactive
   - What's unclear: Does the already-running tap survive a permission revoke, or does macOS kill it immediately?
   - Recommendation: Add a periodic trust check (every 30s) during runtime and surface a warning if revoked; don't rely on the tap to self-report failures

3. **First-launch onboarding: Microphone permission timing**
   - What we know: Phase 1 should request permissions but audio capture is not implemented until Phase 2
   - What's unclear: Whether requesting microphone permission in Phase 1 without an actual AVAudioSession start will confuse the system
   - Recommendation: Request Accessibility in Phase 1 onboarding; defer microphone request to Phase 2 when `AVAudioEngine` is first started (which triggers the system prompt automatically)

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | XCTest (Xcode built-in) |
| Config file | None — Xcode test target configuration |
| Quick run command | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/HotkeyMonitorTests` |
| Full suite command | `xcodebuild test -scheme Typeness -destination 'platform=macOS'` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-01 | App launches with no Dock icon | smoke | Manual verify at launch | Manual-only |
| UI-03 | Settings window opens from menu bar | smoke | Manual verify click | Manual-only |
| UI-04 | Model download progress visible | unit | `TypenessTests/ModelManagerTests::testProgressReporting` | Wave 0 |
| SYS-01 | SMAppService registers/unregisters correctly | unit | `TypenessTests/SettingsStoreTests::testLaunchAtLoginToggle` | Wave 0 |
| SYS-02 | Onboarding shown on first launch only | unit | `TypenessTests/OnboardingTests::testFirstLaunchFlag` | Wave 0 |
| SYS-03 | Accessibility check runs at startup | unit | `TypenessTests/HotkeyMonitorTests::testAXTrustCheck` | Wave 0 |
| HOTKEY-01 | Toggle hotkey fires globally | integration | Manual: 20 consecutive activations | Manual-only |
| HOTKEY-02 | PTT hotkey keyDown/keyUp pair fires | integration | Manual: hold + release test | Manual-only |
| HOTKEY-03 | Hotkey config persists to UserDefaults | unit | `TypenessTests/SettingsStoreTests::testHotkeyPersistence` | Wave 0 |
| HOTKEY-04 | Hotkey fires in third-party app context | integration | Manual: switch to another app, test hotkey | Manual-only |
| HOTKEY-05 | Event suppressed (not passed to active app) | integration | Manual: type in TextEdit, verify no spurious characters | Manual-only |

**Note:** CGEventTap-based hotkeys cannot be unit-tested in isolation without a running run loop and Accessibility permission; manual integration tests are the appropriate verification for HOTKEY-01/02/04/05.

### Sampling Rate

- **Per task commit:** `xcodebuild build -scheme Typeness -destination 'platform=macOS'` (compile-time gate only)
- **Per wave merge:** `xcodebuild test -scheme Typeness -destination 'platform=macOS'`
- **Phase gate:** Full suite green + manual hotkey/permissions smoke test before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `TypenessTests/HotkeyMonitorTests.swift` — covers SYS-03 (AX trust check)
- [ ] `TypenessTests/SettingsStoreTests.swift` — covers SYS-01 (SMAppService), HOTKEY-03 (persistence)
- [ ] `TypenessTests/ModelManagerTests.swift` — covers UI-04 (download progress)
- [ ] `TypenessTests/OnboardingTests.swift` — covers SYS-02 (first launch flag)

---

## Sources

### Primary (HIGH confidence)

- [Apple Developer Docs — MenuBarExtra](https://developer.apple.com/documentation/SwiftUI/MenuBarExtra) — MenuBarExtra scene, window style
- [Apple Developer Docs — CGEventTap](https://developer.apple.com/documentation/coregraphics/cgeventtap) — tap creation, event mask
- [Apple Developer Docs — CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout) — timeout re-enable pattern
- [Apple Developer Docs — SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — login item registration
- [Apple Developer Docs — AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459002-axisprocesstrustedwithoptions) — Accessibility permission check
- [github.com/sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — onKeyDown/onKeyUp confirmed; Carbon backend confirmed
- [FB15168205 — RegisterEventHotKey Option-key bug macOS 15](https://github.com/feedback-assistant/reports/issues/552) — confirms Carbon broken for Option-key on macOS 15

### Secondary (MEDIUM confidence)

- [steipete.me — Showing Settings from macOS Menu Bar Items (2025)](https://steipete.me/posts/2025/showing-settings-from-macos-menu-bar-items) — hidden window + activation policy workaround, verified working
- [nilcoalescing.com — Build a macOS menu bar utility in SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — MenuBarExtra window style pattern
- [nilcoalescing.com — Launch at Login Setting](https://nilcoalescing.com/blog/LaunchAtLoginSetting/) — SMAppService status-as-source-of-truth pattern
- [developer.apple.com forums — CGEventTap preferred approach](https://developer.apple.com/forums/thread/735223) — Apple engineer recommendation for CGEventTap over Carbon
- [AeroSpace issue — CGEventTap reliability investigation](https://github.com/nikitabobko/AeroSpace/issues/1012) — confirms tapDisabledByTimeout handling pattern

### Tertiary (LOW confidence — needs validation)

- KeyboardShortcuts recorder UI + CGEventTap coexistence — not directly verified; inferred from separate code paths

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are first-party system frameworks with official documentation; CGEventTap vs Carbon decision verified by official bug report
- Architecture: HIGH — patterns are well-established in the macOS menu bar app ecosystem; Settings window workaround verified by 2025 implementation report
- Pitfalls: HIGH for CGEventTap/Carbon/AX issues (verified by official docs and bug reports); MEDIUM for KeyboardShortcuts coexistence (inferred, not tested)

**Research date:** 2026-03-16
**Valid until:** 2026-09-16 (stable platform APIs; recheck if macOS 26/Tahoe changes Settings scene behavior — one source noted openSettings may have issues on macOS 26)
