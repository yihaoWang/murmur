# Architecture Research

**Domain:** Native macOS voice-to-text input tool (menu bar app)
**Researched:** 2026-03-16
**Confidence:** HIGH (core macOS APIs), MEDIUM (whisper.cpp Metal via SPM), HIGH (MLX Swift)

## Standard Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer (SwiftUI)                        │
│  ┌─────────────┐  ┌──────────────────┐  ┌────────────────────┐  │
│  │  MenuBarApp │  │  StatusItemView  │  │  SettingsWindow    │  │
│  │  (NSApp)    │  │  (popover/menu)  │  │  (SwiftUI Sheet)   │  │
│  └──────┬──────┘  └────────┬─────────┘  └────────────────────┘  │
│         │                  │                                      │
├─────────┴──────────────────┴─────────────────────────────────────┤
│                    Orchestration Layer                            │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │              RecordingCoordinator (Actor)                  │   │
│  │   state machine: idle → recording → transcribing → done   │   │
│  └──────┬──────────────────┬────────────────────┬────────────┘   │
│         │                  │                    │                  │
├─────────┴──────────────────┴────────────────────┴────────────────┤
│                      Service Layer                                │
│  ┌──────────────┐  ┌────────────────┐  ┌─────────────────────┐  │
│  │ AudioCapture │  │  WhisperBridge │  │  LLMPostProcessor   │  │
│  │ (AVAudio-    │  │  (whisper.cpp  │  │  (MLX Swift MLXLLM) │  │
│  │  Engine)     │  │   C bridge)    │  │                     │  │
│  └──────┬───────┘  └───────┬────────┘  └──────────┬──────────┘  │
│         │                  │                       │              │
├─────────┴──────────────────┴───────────────────────┴─────────────┤
│                      System Layer                                 │
│  ┌──────────────────┐  ┌──────────────────────────────────────┐  │
│  │  HotkeyMonitor   │  │       TextInserter                   │  │
│  │  (CGEventTap)    │  │  (AXUIElement + clipboard fallback)  │  │
│  └──────────────────┘  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────────┐ │
│  │  ModelManager (download progress, path resolution, caching) │ │
│  └──────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| MenuBarApp | App entry point, NSStatusItem lifecycle, LSUIElement config | RecordingCoordinator, SettingsStore |
| StatusItemView | Menu bar icon + popover UI, recording state indicator | RecordingCoordinator (observed state) |
| SettingsWindow | SwiftUI settings sheet: hotkeys, model, debug mode | SettingsStore (UserDefaults) |
| RecordingCoordinator | State machine orchestrating full transcription pipeline | AudioCapture, WhisperBridge, LLMPostProcessor, TextInserter |
| AudioCapture | AVAudioEngine tap, 16kHz mono PCM buffer accumulation | RecordingCoordinator (pushes Float32 buffers) |
| WhisperBridge | C-interop wrapper for whisper.cpp, Metal-accelerated inference | RecordingCoordinator (sync or async transcription) |
| LLMPostProcessor | MLX Swift MLXLLM inference for punctuation/formatting | RecordingCoordinator (string in, string out) |
| HotkeyMonitor | CGEventTap for global shortcut detection (toggle + PTT) | RecordingCoordinator (triggers start/stop) |
| TextInserter | AXUIElement text insertion at cursor, clipboard fallback | RecordingCoordinator (receives final text) |
| ModelManager | Download whisper + LLM models, verify checksums, expose paths | WhisperBridge, LLMPostProcessor, StatusItemView |
| SettingsStore | UserDefaults persistence: hotkeys, model choice, debug flag | All components (read settings) |

## Recommended Project Structure

```
Typeness/
├── App/
│   ├── TypenessApp.swift          # @main, MenuBarExtra scene
│   ├── AppDelegate.swift          # NSApplicationDelegate, LSUIElement
│   └── SettingsStore.swift        # UserDefaults @AppStorage wrapper
│
├── UI/
│   ├── StatusItemView.swift        # Menu bar popover content
│   ├── SettingsView.swift          # Settings sheet
│   ├── HotkeyRecorderView.swift    # Hotkey capture UI
│   └── ModelDownloadView.swift     # Download progress UI
│
├── Core/
│   ├── RecordingCoordinator.swift  # Main orchestrator actor
│   ├── AppState.swift              # Observable state (recording, transcribing, etc.)
│   └── RecordingSession.swift      # Transient per-session data (buffers, results)
│
├── Audio/
│   ├── AudioCapture.swift          # AVAudioEngine tap, format conversion
│   └── AudioBuffer.swift           # Float32 PCM buffer type
│
├── Transcription/
│   ├── WhisperBridge.swift         # Swift wrapper for whisper.cpp C API
│   └── WhisperContext.swift        # whisper_context lifecycle management
│
├── LLM/
│   ├── LLMPostProcessor.swift      # MLX Swift model loading + generation
│   └── PromptBuilder.swift         # System prompt + text formatting template
│
├── Input/
│   ├── HotkeyMonitor.swift         # CGEventTap global shortcut listener
│   └── TextInserter.swift          # AXUIElement + NSPasteboard fallback
│
├── Models/
│   ├── ModelManager.swift          # Download, cache, verify models
│   └── ModelRegistry.swift         # Known model URLs and checksums
│
└── Debug/
    └── DebugRecorder.swift         # WAV + JSON save for debug mode
```

### Structure Rationale

- **App/:** Entry point and global settings isolated; SwiftUI `@main` with `MenuBarExtra` scene keeps boilerplate minimal
- **Core/:** `RecordingCoordinator` is the only component allowed to drive the pipeline — all others are passive services called by it
- **Audio/**, **Transcription/**, **LLM/**, **Input/:** Each subsystem is a vertical slice that can be developed and tested in isolation
- **Models/:** Separated because model management (download, verification) is I/O-heavy and distinct from inference logic

## Architectural Patterns

### Pattern 1: Actor-Based Pipeline Orchestration

**What:** `RecordingCoordinator` is a Swift `actor`, giving it serialized state mutation. All pipeline stages are `async` calls chained within the actor.

**When to use:** Any time shared mutable state (recording status, current session) is accessed from multiple call sites (hotkey events, UI, background processing).

**Trade-offs:** Prevents data races with zero locks. Hop cost to actor is negligible (~microseconds). Xcode's actor isolation warnings guide correct usage.

**Example:**
```swift
actor RecordingCoordinator {
    enum State { case idle, recording, transcribing, inserting }
    private(set) var state: State = .idle

    func startRecording() async throws {
        guard state == .idle else { return }
        state = .recording
        try await audioCapture.start()
    }

    func stopAndTranscribe() async throws {
        guard state == .recording else { return }
        state = .transcribing
        let pcm = await audioCapture.stop()
        let raw = try await whisper.transcribe(pcm)
        let formatted = try await llm.format(raw)
        state = .inserting
        try await textInserter.insert(formatted)
        state = .idle
    }
}
```

### Pattern 2: C Interop via Thin Swift Wrapper

**What:** whisper.cpp exposes a C API (`whisper_init_from_file`, `whisper_full`, `whisper_full_get_segment_text`). Wrap it in a final Swift class with a clear async boundary.

**When to use:** Any C library integration — keep all unsafe pointer code inside one file.

**Trade-offs:** Hides all `UnsafePointer` and `UnsafeMutablePointer` from the rest of the app. The wrapper must manage C memory lifetime carefully.

**Example:**
```swift
final class WhisperBridge {
    private var ctx: OpaquePointer?

    init(modelPath: URL) throws {
        ctx = whisper_init_from_file(modelPath.path)
        guard ctx != nil else { throw WhisperError.modelLoadFailed }
    }

    func transcribe(_ samples: [Float]) async throws -> String {
        // Run on a dedicated background thread — blocks
        return try await Task.detached(priority: .userInitiated) {
            var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
            params.language = "zh"
            whisper_full(self.ctx, params, samples, Int32(samples.count))
            // Collect segments...
        }.value
    }

    deinit { whisper_free(ctx) }
}
```

### Pattern 3: Observed State via @Observable

**What:** `AppState` is an `@Observable` class (macOS 14+) holding UI-visible state. `RecordingCoordinator` mutates it; SwiftUI views observe it.

**When to use:** Any state that drives UI updates across multiple views (status icon, popover, menu bar icon animation).

**Trade-offs:** `@Observable` requires macOS 14+, which matches the project's minimum deployment target. Cleaner than `ObservableObject` + `@Published` boilerplate.

**Example:**
```swift
@Observable final class AppState {
    var phase: RecordingPhase = .idle
    var lastTranscription: String = ""
    var modelDownloadProgress: Double? = nil
    var errorMessage: String? = nil
}
```

## Data Flow

### Primary Flow: Hotkey → Text at Cursor

```
User presses hotkey
    ↓
HotkeyMonitor (CGEventTap, background thread)
    ↓ (calls actor)
RecordingCoordinator.startRecording()
    ↓
AudioCapture begins AVAudioEngine tap
    ↓ (accumulates Float32 PCM at 16kHz mono)
User releases hotkey / presses again
    ↓
RecordingCoordinator.stopAndTranscribe()
    ↓
AudioCapture.stop() → [Float] buffer
    ↓
WhisperBridge.transcribe([Float]) → raw String (Metal GPU, background thread)
    ↓
LLMPostProcessor.format(String) → polished String (MLX, background thread)
    ↓
TextInserter.insert(String)
    │── AXUIElement kAXSelectedTextAttribute (preferred)
    └── NSPasteboard + Cmd+V simulation (fallback)
    ↓
AppState updated → StatusItemView refreshes
```

### Model Initialization Flow (App Startup)

```
App launches
    ↓
ModelManager.verifyModels()
    ├── Models present? → load into WhisperBridge + LLMPostProcessor (background)
    └── Missing? → show download progress in StatusItemView
                       ↓
                  URLSession download to ~/Library/Application Support/Typeness/
                       ↓
                  Checksum verify → load models
```

### Settings Flow

```
SettingsStore (UserDefaults @AppStorage)
    ↓ (read at init)
HotkeyMonitor — registers CGEventTap for configured key combo
RecordingCoordinator — reads confirm-before-insert flag
WhisperBridge — reads model path
LLMPostProcessor — reads model path
```

## Integration Points

### External Libraries

| Library | Integration | Notes |
|---------|-------------|-------|
| whisper.cpp | Swift Package from `ggml-org/whisper.cpp` (direct, not whisper.spm — archived) | Metal enabled via build flags; `whisper-metal` target |
| mlx-swift-examples (MLXLLM) | Swift Package Manager dependency | Provides `LLMModelFactory`, `ChatSession` API |
| KeyboardShortcuts (sindresorhus) | SPM — wraps `CGEventTap` + `RegisterEventHotKey` | Supports user-configurable shortcuts with SwiftUI integration |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| HotkeyMonitor → RecordingCoordinator | Actor async call | CGEventTap fires on background thread; actor hop is safe |
| AudioCapture → RecordingCoordinator | Async buffer delivery (continuation or AsyncStream) | AVAudioEngine tap callback is real-time thread — must not block |
| WhisperBridge ↔ RecordingCoordinator | `async throws` function call | whisper_full is synchronous C — wrap in `Task.detached` |
| LLMPostProcessor ↔ RecordingCoordinator | `async throws` function returning String | MLX inference is blocking; run off main actor |
| TextInserter → System | AXUIElement C API calls | Must request Accessibility permission at first run |

## Anti-Patterns

### Anti-Pattern 1: Running Audio Tap Work on the Main Actor

**What people do:** Call `@MainActor` methods from the AVAudioEngine installTap callback.

**Why it's wrong:** The tap callback runs on a real-time audio thread. Hopping to the main actor adds latency and can cause audio glitches or buffer overruns.

**Do this instead:** Accumulate PCM data into a thread-safe buffer (actor or `Mutex`) from the tap callback. Deliver the complete buffer to the coordinator only after recording stops.

### Anti-Pattern 2: Loading whisper Model on First Transcription

**What people do:** Defer `whisper_init_from_file` to the first transcription request (lazy loading).

**Why it's wrong:** Large model load (2-5 seconds for large-v3-turbo) blocks the user's first transcription attempt and looks like a crash or hang.

**Do this instead:** Load the whisper context at app startup in `ModelManager`, in the background, showing a progress indicator in the menu bar icon.

### Anti-Pattern 3: Hardcoding Text Insertion via Clipboard Only

**What people do:** Always use `NSPasteboard` + simulated Cmd+V for text insertion (simpler to implement).

**Why it's wrong:** Overwrites the user's clipboard and triggers paste indicators in target apps. Fails in apps that don't support Cmd+V (terminal emulators with custom paste, games).

**Do this instead:** Try `AXUIElementSetAttributeValue(kAXSelectedTextAttribute)` first (inserting at cursor without clipboard); fall back to clipboard only if accessibility fails.

### Anti-Pattern 4: One Swift Actor for All ML Work

**What people do:** Put both whisper and MLX inference in the same actor.

**Why it's wrong:** Both are compute-heavy and GPU-bound. Serializing them through one actor means they cannot overlap. The actor's serial executor adds unnecessary queueing.

**Do this instead:** Use `Task.detached(priority: .userInitiated)` for each independently. Let the OS scheduler and Metal/unified memory arbitrate GPU access.

### Anti-Pattern 5: Registering CGEventTap Without Checking Accessibility Permission First

**What people do:** Register the event tap and silently fail when it returns nil.

**Why it's wrong:** CGEventTap returns nil without Accessibility permission — the app appears to ignore all hotkeys with no feedback.

**Do this instead:** Check `AXIsProcessTrustedWithOptions` at startup, prompt the user to grant permission if missing, and re-register the tap after the permission dialog is closed.

## Build Order Implications

The component dependency graph suggests this build sequence:

```
1. SettingsStore          ← no dependencies, needed by everything
2. ModelManager           ← depends on SettingsStore (model paths)
3. AudioCapture           ← standalone, AVAudioEngine only
4. WhisperBridge          ← depends on ModelManager (model path)
5. LLMPostProcessor       ← depends on ModelManager (model path)
6. HotkeyMonitor          ← depends on SettingsStore (hotkey config)
7. TextInserter           ← standalone (Accessibility API)
8. RecordingCoordinator   ← depends on 3–7
9. AppState + UI          ← depends on RecordingCoordinator
```

Each layer can be independently tested with a harness before the next is built. Phases should follow this order.

## Sources

- [whisper.cpp Swift Package (ggml-org)](https://github.com/ggml-org/whisper.cpp) — official repo, replaces whisper.spm
- [whisper.spm archived notice](https://github.com/ggerganov/whisper.spm) — confirms to use main repo directly
- [MLX Swift examples — model loading API](https://github.com/ml-explore/mlx-swift-examples)
- [KeyboardShortcuts — CGEventTap wrapper](https://github.com/soffes/HotKey)
- [AXUIElement documentation](https://developer.apple.com/documentation/applicationservices/axuielement)
- [CGEventTap preferred over Carbon RegisterEventHotKey](https://developer.apple.com/forums/thread/735223)
- [macOS 15 RegisterEventHotKey Option-key bug](https://github.com/feedback-assistant/reports/issues/552)
- [MLX WWDC25 session](https://developer.apple.com/videos/play/wwdc2025/298/)
- [AVAudioEngine documentation](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [SwiftUI MenuBarExtra — nil coalescing blog](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/)

---
*Architecture research for: native macOS voice-to-text menu bar app (Typeness Swift)*
*Researched: 2026-03-16*
