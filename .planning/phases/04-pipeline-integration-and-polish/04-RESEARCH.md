# Phase 4: Pipeline Integration and Polish - Research

**Researched:** 2026-03-17
**Domain:** SwiftUI state machine wiring, macOS menu bar icon states, WAV file I/O, SwiftUI confirmation sheet
**Confidence:** HIGH (all patterns directly observable in existing codebase; no new dependencies required)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| UI-02 | Menu bar icon shows status states (idle, recording, processing, error) | `MenuBarExtra` uses `systemImage:` — can be driven by a computed property on `AppState.recordingState`; distinct SF Symbols per state confirmed available |
| STT-04 | App displays transcription latency in menu bar or status area | `AppState` needs `lastTranscriptionLatency: TimeInterval?`; `ContinuousClock` / `Date` diff gives ms precision; display in `StatusItemView` |
| DEBUG-01 | User can enable debug mode in settings | `SettingsStore` already has `@AppStorage("debugModeEnabled") var debugModeEnabled: Bool = false` — toggle just needs UI surface in SettingsView |
| DEBUG-02 | Debug mode saves recordings as WAV files with JSON metadata | `AVAudioFile` writes LPCM WAV; JSON struct encoded with `JSONEncoder`; save to `~/Library/Application Support/Typeness/DebugRecordings/` |
| DEBUG-03 | User can enable confirm-before-insert mode in settings | `SettingsStore` already has `@AppStorage("confirmBeforeInsert") var confirmBeforeInsert: Bool = false` — toggle needs UI surface |
| DEBUG-04 | Confirm mode shows transcribed text for review before insertion | SwiftUI sheet or panel driven by `AppState.pendingTranscription: String?`; user confirms or cancels |
</phase_requirements>

---

## Summary

Phase 4 is a pure integration and wiring phase. All component engines (`AudioCaptureEngine`, `TranscriptionEngine`, `PostProcessingEngine`, `TextInsertionEngine`) exist after Phase 3. The work is:

1. Extend `AppState.RecordingState` with `.processing` (post-transcription LLM step) and `.error` states to support UI-02.
2. Wire `TypenessApp.handleRecordingStop()` to call `PostProcessingEngine.format(_:)` and `TextInsertionEngine.insert(_:)` after transcription completes, respecting the `confirmBeforeInsert` flag.
3. Make the `MenuBarExtra` icon image dynamic, driven by `appState.recordingState`.
4. Display latency (STT-04) in `StatusItemView` using a new `AppState.lastTranscriptionLatency` property.
5. Add debug-mode WAV + JSON archiving using `AVAudioFile` when `settingsStore.debugModeEnabled` is true.
6. Add settings toggles for debug mode and confirm-before-insert to `SettingsView`.
7. Implement the confirm-before-insert review panel (DEBUG-04).

No new SPM dependencies are required. All APIs are system frameworks already imported or in use.

**Primary recommendation:** Centralize all pipeline coordination in `TypenessApp.handleRecordingStop()` as a linear `async` function — capture start time, transcribe, optionally post-process, optionally confirm, insert, archive if debug. Keep `AppState` as the single source of truth for all UI state transitions.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AVFoundation (system) | macOS 14+ | Write WAV files via `AVAudioFile` | Already imported; handles LPCM header automatically |
| Foundation (system) | macOS 14+ | `JSONEncoder`, file I/O, `Date`/`ContinuousClock` | Already imported |
| SwiftUI (system) | macOS 14+ | Confirmation sheet, settings toggles | Already used throughout |
| AppKit (system) | macOS 14+ | `NSImage` for dynamic menu bar icon | Already imported |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Observation (system) | macOS 17+ / Swift 5.9 | `@Observable` on `AppState` | Already used; add new published properties following existing pattern |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `AVAudioFile` WAV write | Manual RIFF header + `write(_:)` | `AVAudioFile` handles LPCM/WAV encoding automatically; no reason to hand-roll |
| SwiftUI `.sheet` for confirm | `NSPanel` or `NSAlert` | SwiftUI sheet is consistent with existing codebase pattern (OnboardingView uses sheet); `NSAlert` works but mixes paradigms |
| SF Symbols for icon states | Custom PNG assets | SF Symbols cover all needed states, scale with system, no asset management |

**Installation:** No new dependencies. All required frameworks are already in use.

---

## Architecture Patterns

### Recommended Project Structure Additions
```
Typeness/
├── App/
│   ├── TypenessApp.swift          # pipeline wiring, all handleRecording* methods updated
│   └── AppState.swift             # add .processing, .error states; lastTranscriptionLatency; pendingTranscription
├── Core/
│   └── DebugArchiver.swift        # new: WAV + JSON save logic
├── UI/
│   ├── StatusItemView.swift       # add latency display
│   ├── SettingsView.swift         # add debug + confirm toggles
│   └── ConfirmInsertView.swift    # new: confirm-before-insert review panel
```

### Pattern 1: Extended RecordingState enum
**What:** Add `.processing` and `.error` cases to `AppState.RecordingState` so the pipeline has four distinct visual states.
**When to use:** Each pipeline step transitions to the correct state.
**Example:**
```swift
// In AppState.swift
enum RecordingState {
    case idle
    case recording
    case transcribing    // existing — Whisper inference
    case processing      // NEW — LLM post-processing
    case error(String)   // NEW — holds a short message for display
}
```

Note: `error` as an associated-value case requires care in SwiftUI comparisons — use a helper `var isError: Bool` computed property rather than pattern-matching in view code.

### Pattern 2: Dynamic MenuBarExtra icon
**What:** Bind `MenuBarExtra`'s `systemImage:` parameter to a computed property on `AppState`.

macOS 14 `MenuBarExtra` does NOT support dynamic `systemImage` binding directly via a `@State` variable in the `App` struct — the `systemImage` string in `MenuBarExtra("Typeness", systemImage: ...)` is part of the scene declaration and is evaluated at init time. The correct approach is to put the icon logic inside the extra's label view using a custom label closure.

```swift
// In TypenessApp.body:
MenuBarExtra {
    StatusItemView(appState: appState, modelManager: modelManager)
} label: {
    Image(systemName: appState.menuBarIconName)
        .symbolRenderingMode(.hierarchical)
}
.menuBarExtraStyle(.window)
```

```swift
// In AppState.swift:
var menuBarIconName: String {
    switch recordingState {
    case .idle:        return "mic"
    case .recording:   return "mic.fill"
    case .transcribing, .processing: return "waveform"
    case .error:       return "exclamationmark.triangle"
    }
}
```

**Confidence:** HIGH — the label closure form is the standard pattern for dynamic menu bar icons.

### Pattern 3: Latency measurement
**What:** Wrap the `transcribe + format` pipeline in a `ContinuousClock` measurement and store the result in `AppState`.

```swift
// In TypenessApp.handleRecordingStop():
let clock = ContinuousClock()
let start = clock.now
let text = try await transcriptionEngine.transcribe(audioFrames: frames)
let elapsed = clock.now - start
await MainActor.run {
    appState.lastTranscriptionLatency = elapsed.formatted()
}
```

`ContinuousClock` is available from Swift 5.7 / macOS 13+. `Duration.formatted()` returns a localized string like "1.23 sec". For display, a manual `String(format: "%.0f ms", elapsed.components.attoseconds / 1_000_000_000_000_000)` is cleaner for sub-second values.

Simpler alternative: use `Date()` before/after and compute `timeInterval`:

```swift
let start = Date()
let text = try await transcriptionEngine.transcribe(audioFrames: frames)
let latencyMs = Date().timeIntervalSince(start) * 1000
await MainActor.run {
    appState.lastTranscriptionLatency = latencyMs  // Double, milliseconds
}
```

**Recommendation:** Use `Date` approach — simpler, no formatting complexity, consistent with existing codebase style.

### Pattern 4: WAV archiving with AVAudioFile (DEBUG-02)
**What:** Convert `[Float]` captured audio to a WAV file using `AVAudioFile` in write mode.

```swift
// Source: AVFoundation AVAudioFile documentation
import AVFoundation

struct DebugArchiver {
    static let directory: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Typeness/DebugRecordings")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    struct SessionMetadata: Codable {
        let timestamp: Date
        let transcription: String
        let formattedText: String
        let latencyMs: Double
        let audioFrameCount: Int
        let insertionPath: String  // "accessibility" or "clipboardPaste"
    }

    static func save(
        frames: [Float],
        transcription: String,
        formattedText: String,
        latencyMs: Double,
        insertionPath: String
    ) throws {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let base = formatter.string(from: timestamp)

        let wavURL = directory.appendingPathComponent("\(base).wav")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!
        let file = try AVAudioFile(forWriting: wavURL, settings: format.settings)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames.count))!
        buffer.frameLength = buffer.frameCapacity
        let channelData = buffer.floatChannelData![0]
        for (i, sample) in frames.enumerated() {
            channelData[i] = sample
        }
        try file.write(from: buffer)

        let meta = SessionMetadata(
            timestamp: timestamp,
            transcription: transcription,
            formattedText: formattedText,
            latencyMs: latencyMs,
            audioFrameCount: frames.count,
            insertionPath: insertionPath
        )
        let jsonURL = directory.appendingPathComponent("\(base).json")
        let data = try JSONEncoder().encode(meta)
        try data.write(to: jsonURL)
    }
}
```

**Key detail:** `AVAudioFile(forWriting:settings:)` requires a settings dictionary, not an `AVAudioFormat` directly. Use `format.settings` to get the dictionary. WAV output requires `kAudioFormatLinearPCM` — `AVAudioFormat(commonFormat: .pcmFormatFloat32 ...)` gives exactly this.

### Pattern 5: Confirm-before-insert sheet (DEBUG-04)
**What:** When `confirmBeforeInsert` is enabled, set `appState.pendingTranscription` instead of calling `insert` immediately. A SwiftUI sheet observes this and presents a review UI.

```swift
// In AppState.swift:
var pendingTranscription: String? = nil  // non-nil = sheet should show
```

```swift
// In TypenessApp (or StatusItemView containing sheet):
.sheet(item: ...) // or:
.sheet(isPresented: Binding(
    get: { appState.pendingTranscription != nil },
    set: { if !$0 { appState.pendingTranscription = nil } }
)) {
    ConfirmInsertView(
        text: appState.pendingTranscription ?? "",
        onConfirm: { text in
            Task { textInsertionEngine.insert(text) }
            appState.pendingTranscription = nil
            appState.recordingState = .idle
        },
        onCancel: {
            appState.pendingTranscription = nil
            appState.recordingState = .idle
        }
    )
}
```

**Sheet attachment point:** The sheet must attach to a visible window. The `MenuBarExtra` window (`.menuBarExtraStyle(.window)`) is the appropriate anchor — attach the `.sheet` modifier inside `StatusItemView` or wrap in the extra's content view.

**Alternative:** Use a standalone `NSPanel` (floating panel). This works without a visible anchor window and may be preferable so the confirm view appears near the cursor. However, it requires AppKit setup and breaks the pure SwiftUI pattern. Recommendation: start with SwiftUI sheet; if UX is poor (sheet inside menu bar extra closes when clicking away), revisit with `NSPanel`.

### Anti-Patterns to Avoid
- **Mutating `AppState` from background threads:** Always wrap `appState.*` mutations in `await MainActor.run { }` or mark the update site `@MainActor`. `@Observable` does not enforce main-thread access at the property level.
- **Attaching `.sheet` to a `Window` scene with zero size:** The existing hidden window has `frame(width: 0, height: 0)`. Sheets attached to it may not display correctly. Attach confirmation sheet to `MenuBarExtra` content instead.
- **Writing WAV with wrong format settings:** Using `AVAudioFile(forWriting:settings:)` with the format's `settings` dictionary is the correct path. Do not construct the settings dictionary manually — wrong keys cause silent write failures.
- **Storing `lastTranscriptionLatency` as formatted string:** Store as `Double` (milliseconds) in `AppState` and format at the display site. This allows unit tests to assert numeric values.
- **Using `.transcribing` state for both Whisper and LLM steps:** The icon would show the same state for both — add `.processing` so the user sees distinct feedback for the LLM step.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| WAV file writing | Manual RIFF/WAVE header construction | `AVAudioFile(forWriting:settings:)` | AVFoundation handles chunked I/O, header, sample format |
| JSON metadata | Custom string concatenation | `JSONEncoder` with `Codable` struct | Type safety, proper escaping, date formatting |
| Latency timing | `mach_absolute_time()` + calibration | `Date()` before/after | Sufficient precision for ms display; simpler |
| Animated icon (recording pulse) | Custom `NSStatusItem` with `NSTimer` | SF Symbol `.variableValue` or accept static icon | Animation requires `NSStatusItem` direct access, complex setup; static icon change is sufficient for v1 |

---

## Common Pitfalls

### Pitfall 1: MenuBarExtra systemImage not dynamically updating
**What goes wrong:** Setting `systemImage:` directly in `MenuBarExtra("Typeness", systemImage: appState.menuBarIconName)` — this does not update when `appState` changes in macOS 14+.
**Why it happens:** `MenuBarExtra` scene-level parameters are evaluated at scene construction, not on each body re-evaluation.
**How to avoid:** Use the label closure form: `MenuBarExtra { ... } label: { Image(systemName: appState.menuBarIconName) }`.
**Warning signs:** Icon never changes from the initial value.

### Pitfall 2: Confirmation sheet dismissed when menu bar extra loses focus
**What goes wrong:** The `MenuBarExtra` window auto-dismisses when the user clicks elsewhere. A `.sheet` inside it also dismisses.
**Why it happens:** `MenuBarExtra` with `.window` style behaves like a popover — it closes on outside click. This closes any sheet attached to it.
**How to avoid:** Present the confirmation as a separate `Window` scene with a flag in `AppState`, or use a floating `NSPanel` that can stay on screen. For v1, document this behavior and ensure the menu bar stays open (or use `openWindow` action to show a dedicated confirm window).
**Warning signs:** Confirm sheet appears briefly then disappears.

### Pitfall 3: Debug WAV directory not created before first write
**What goes wrong:** `AVAudioFile(forWriting:)` throws if the parent directory does not exist.
**Why it happens:** `~/Library/Application Support/Typeness/DebugRecordings/` does not exist on first run.
**How to avoid:** Call `FileManager.default.createDirectory(at:withIntermediateDirectories: true)` before the first write. Do this in `DebugArchiver` initializer or as a static setup step. `withIntermediateDirectories: true` is safe to call even if directory exists.
**Warning signs:** Debug WAV save throws `NSFileWriteNoPermission` or `NSFileNoSuchFileError` on first use.

### Pitfall 4: AppState mutation from TranscriptionEngine actor context
**What goes wrong:** Calling `appState.recordingState = .idle` from inside a `Task` that runs on the `TranscriptionEngine` actor executor causes a main-thread constraint warning or race.
**Why it happens:** `AppState` is `@Observable` but not `@MainActor`. Mutations from background actors are technically unsafe.
**How to avoid:** All `appState.*` writes in `TypenessApp` are already on the main actor (the methods are called from `NotificationCenter` observers on `.main` queue). Preserve this — do not move state mutations into actor methods.
**Warning signs:** Purple runtime warnings "Publishing changes from background threads is not allowed".

### Pitfall 5: RecordingState .error case breaks existing equality checks
**What goes wrong:** Adding `case error(String)` to `RecordingState` makes the enum non-equatable without a custom `==` implementation. Existing `if appState.recordingState == .idle` comparisons break.
**Why it happens:** Enums with associated values lose synthesized `Equatable` conformance when there is an associated value that is itself `Equatable` but the compiler requires explicit conformance.
**How to avoid:** Add explicit `Equatable` conformance to `RecordingState`, or avoid using `==` on the error case — use `if case .error = appState.recordingState` pattern. Alternatively, keep error state minimal: `var lastError: String? = nil` on `AppState` and keep `RecordingState` to simple cases without associated values.

**Recommendation:** Use a separate `var lastError: String? = nil` on `AppState` rather than `case error(String)`. This avoids the Equatable problem entirely and is cleaner to observe in SwiftUI.

---

## Code Examples

### Dynamic MenuBarExtra label (UI-02)
```swift
// Source: Apple SwiftUI MenuBarExtra documentation
MenuBarExtra {
    StatusItemView(appState: appState, modelManager: modelManager)
} label: {
    Label("Typeness", systemImage: appState.menuBarIconName)
}
.menuBarExtraStyle(.window)
```

```swift
// In AppState.swift:
var menuBarIconName: String {
    switch recordingState {
    case .idle:        return "mic"
    case .recording:   return "mic.fill"
    case .transcribing: return "waveform"
    case .processing:  return "ellipsis.circle"
    }
    // error: appState.lastError != nil → return "exclamationmark.triangle"
}
```

### Latency measurement and display (STT-04)
```swift
// In TypenessApp.handleRecordingStop():
let startTime = Date()
let text = try await transcriptionEngine.transcribe(audioFrames: frames)
let latencyMs = Date().timeIntervalSince(startTime) * 1000
appState.lastTranscriptionLatencyMs = latencyMs

// In StatusItemView:
if let ms = appState.lastTranscriptionLatencyMs {
    Text(String(format: "Last: %.0f ms", ms))
        .font(.caption)
        .foregroundStyle(.secondary)
}
```

### AVAudioFile WAV write (DEBUG-02)
```swift
// Source: AVFoundation AVAudioFile + AVAudioPCMBuffer documentation
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
let file = try AVAudioFile(forWriting: wavURL, settings: format.settings)
let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames.count))!
buffer.frameLength = buffer.frameCapacity
frames.withUnsafeBufferPointer { ptr in
    buffer.floatChannelData![0].update(from: ptr.baseAddress!, count: frames.count)
}
try file.write(from: buffer)
```

### Settings toggles (DEBUG-01, DEBUG-03)
```swift
// In SettingsView GeneralSettingsView — add to Form:
Section("Debug") {
    Toggle("Debug Mode (save recordings)", isOn: $settingsStore.debugModeEnabled)
    Toggle("Confirm Before Insert", isOn: $settingsStore.confirmBeforeInsert)
}
```
These `@AppStorage` properties already exist in `SettingsStore`; only UI surface is missing.

### Full pipeline in handleRecordingStop()
```swift
private func handleRecordingStop() async {
    guard appState.recordingState == .recording else { return }
    let frames = await audioEngine.stop()
    let startTime = Date()
    appState.recordingState = .transcribing

    guard VADGate.hasVoiceActivity(samples: frames) else {
        appState.recordingState = .idle
        return
    }

    do {
        let rawText = try await transcriptionEngine.transcribe(audioFrames: frames)

        // STT-04 latency
        let latencyMs = Date().timeIntervalSince(startTime) * 1000
        appState.lastTranscriptionLatencyMs = latencyMs

        // LLM post-processing
        appState.recordingState = .processing
        let finalText: String
        if postProcessingEngine.isLoaded {
            finalText = try await postProcessingEngine.format(rawText)
        } else {
            finalText = rawText
        }

        // DEBUG-03 / DEBUG-04: confirm before insert
        if settingsStore.confirmBeforeInsert {
            appState.pendingTranscription = finalText
            // insertion happens in ConfirmInsertView onConfirm callback
        } else {
            let path = textInsertionEngine.insert(finalText)
            // DEBUG-02: archive if debug mode
            if settingsStore.debugModeEnabled {
                try? DebugArchiver.save(
                    frames: frames,
                    transcription: rawText,
                    formattedText: finalText,
                    latencyMs: latencyMs,
                    insertionPath: path == .accessibility ? "accessibility" : "clipboardPaste"
                )
            }
            appState.recordingState = .idle
        }
    } catch {
        appState.lastError = error.localizedDescription
        appState.recordingState = .idle
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `NSStatusItem` + custom image swap for icon states | `MenuBarExtra` label closure with `Image(systemName:)` | macOS 13 / SwiftUI 4 | No `NSStatusItem` access needed; SwiftUI-native |
| `MenuBarExtra("Name", systemImage: "icon")` static | Label closure form for dynamic icon | macOS 14+ observation | Required for icon to respond to state changes |

**Deprecated/outdated:**
- `NSStatusItem.image` manual swap: superseded by `MenuBarExtra` label closure in SwiftUI — do not use.
- Hardcoded `systemImage:` string in `MenuBarExtra` declaration: works for static apps, does not update dynamically.

---

## Open Questions

1. **Confirmation sheet dismissal on outside click**
   - What we know: `MenuBarExtra(.window)` auto-dismisses on outside click, taking attached sheets with it.
   - What's unclear: Whether a dedicated `Window` scene (always-open confirm window) or floating `NSPanel` is better UX for v1.
   - Recommendation: Plan should include a task to prototype the sheet approach and fall back to `openWindow` (SwiftUI `Window` scene with `@Environment(\.openWindow)`) if the sheet dismissal is problematic. The `Window` approach requires `NSApp.setActivationPolicy(.regular)` before opening, same pattern used in existing `openSettings()` calls.

2. **PostProcessingEngine availability at Phase 4 start**
   - What we know: Phase 3 plans implement `PostProcessingEngine` and wire `ModelManager.downloadAndLoadLLMIfNeeded`. Phase 4 starts after Phase 3 is verified.
   - What's unclear: Whether Phase 3 execution has wired `postProcessingEngine` into `TypenessApp` or left that for Phase 4.
   - Recommendation: Phase 4 Wave 0 plan should read `TypenessApp.swift` and `PostProcessingEngine.swift` to confirm actual state before writing pipeline code. The Phase 3 plans (03-01, 03-02) create the engines but do not wire them into `TypenessApp.handleRecordingStop()` — that wiring is Phase 4's job.

3. **`TextInsertionEngine` and `PostProcessingEngine` instantiation in TypenessApp**
   - What we know: `TypenessApp` currently has `@State private var audioEngine` and `@State private var transcriptionEngine`. Phase 3 created `PostProcessingEngine` and `TextInsertionEngine` but the plan files do not show them being added to `TypenessApp` state.
   - Recommendation: Phase 4 Wave 0 must add `@State private var postProcessingEngine = PostProcessingEngine()` and `let textInsertionEngine = TextInsertionEngine()` to `TypenessApp` and pass them through to pipeline methods.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing) |
| Config file | Typeness.xcodeproj test target TypenessTests |
| Quick run command | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/PipelineIntegrationTests 2>&1 \| tail -20` |
| Full suite command | `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 \| tail -40` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| UI-02 | `AppState.menuBarIconName` returns correct SF Symbol for each `RecordingState` | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testMenuBarIconNames` | ❌ Wave 0 |
| STT-04 | `AppState.lastTranscriptionLatencyMs` is set after pipeline completes | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testLatencyPropertySet` | ❌ Wave 0 |
| DEBUG-01 | `SettingsStore.debugModeEnabled` persists via `@AppStorage` | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testDebugModeTogglePersists` | ❌ Wave 0 |
| DEBUG-02 | `DebugArchiver.save(...)` creates WAV and JSON files in temp directory | unit | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testDebugArchiverCreatesFiles` | ❌ Wave 0 |
| DEBUG-03 | `SettingsStore.confirmBeforeInsert` persists via `@AppStorage` | unit | XCTSkip or share with DEBUG-01 test | ❌ Wave 0 |
| DEBUG-04 | When `confirmBeforeInsert = true`, pipeline sets `pendingTranscription` and does NOT call insert | unit/manual | `xcodebuild test ... -only-testing TypenessTests/PipelineIntegrationTests/testConfirmModeSetsPendingTranscription` | ❌ Wave 0 |

Note: UI-02 (icon name mapping) and DEBUG-02 (WAV file I/O) are fully testable in unit tests. DEBUG-04 pipeline behavior is testable if `handleRecordingStop` logic is extracted to a testable function, but the integration point in `TypenessApp` cannot be unit-tested without dependency injection. A `XCTSkip` stub is acceptable for the full pipeline test; the `pendingTranscription` state assertion alone is sufficient.

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/PipelineIntegrationTests 2>&1 | tail -20`
- **Per wave merge:** `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 | tail -40`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Tests/TypenessTests/PipelineIntegrationTests.swift` — covers UI-02, STT-04, DEBUG-01, DEBUG-02, DEBUG-03, DEBUG-04 stubs
- [ ] `Typeness/Core/DebugArchiver.swift` — needs to exist as minimal placeholder for build
- [ ] `Typeness/Core/AppState.swift` updates: add `.processing` to `RecordingState`, add `lastTranscriptionLatencyMs: Double?`, `pendingTranscription: String?`, `lastError: String?`, `menuBarIconName: String` computed property

---

## Sources

### Primary (HIGH confidence)
- Direct inspection of `Typeness/App/TypenessApp.swift` (2026-03-17) — current pipeline state, existing state machine
- Direct inspection of `Typeness/Core/AppState.swift` (2026-03-17) — `RecordingState` enum, existing properties
- Direct inspection of `Typeness/App/SettingsStore.swift` (2026-03-17) — `debugModeEnabled` and `confirmBeforeInsert` keys already exist
- Direct inspection of `Typeness/UI/StatusItemView.swift` (2026-03-17) — current menu bar content
- Direct inspection of `Typeness/Core/TextInsertionEngine.swift` (2026-03-17) — insertion API confirmed
- Apple AVFoundation documentation — `AVAudioFile(forWriting:settings:)`, `AVAudioPCMBuffer` write pattern
- SwiftUI `MenuBarExtra` documentation — label closure form for dynamic icon

### Secondary (MEDIUM confidence)
- Phase 3 RESEARCH.md patterns (2026-03-17) — `PostProcessingEngine` API, `DebugArchiver` save path convention

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies; all frameworks in active use
- Architecture: HIGH — patterns derived directly from existing codebase inspection
- Pitfalls: HIGH — `MenuBarExtra` dynamic icon limitation and `RecordingState` associated-value Equatable issue verified through code inspection; WAV write pattern from official AVFoundation docs

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (all system frameworks stable; no third-party dependency changes)
