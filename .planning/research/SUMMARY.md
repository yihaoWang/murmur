# Project Research Summary

**Project:** Typeness Swift — Native macOS Voice-to-Text Input Tool
**Domain:** macOS menu bar dictation app with local AI transcription and LLM post-processing
**Researched:** 2026-03-16
**Confidence:** HIGH

## Executive Summary

Typeness is a native macOS menu bar app that captures microphone input via global hotkey, transcribes speech locally using whisper.cpp with Metal GPU acceleration, optionally post-processes the result with a local LLM (Qwen3-1.7B via MLX Swift), and inserts the final text at the cursor in whatever app the user is focused on. The recommended approach is a Swift 6 actor-based pipeline with a central `RecordingCoordinator` actor orchestrating five independent service layers: audio capture (AVFoundation), transcription (whisper.cpp), LLM formatting (mlx-swift-lm), hotkey monitoring (KeyboardShortcuts/CGEventTap), and text insertion (Accessibility API + clipboard fallback). SwiftUI `MenuBarExtra` with the window style handles all UI. This is a well-understood app category with established macOS patterns — the key differentiator is the local LLM post-processing for Traditional Chinese punctuation, which no competitor currently does on-device.

The most dangerous risks are all infrastructure-level and must be addressed in the earliest phases: CGEventTap's silent timeout-disable behavior, Accessibility API permission being revoked on each Xcode rebuild, audio sample rate mismatch (AVAudioEngine delivers 44.1/48kHz; whisper.cpp requires 16kHz mono Float32), and whisper.cpp hallucinations on silence. These pitfalls have well-known mitigations but will cause subtle, hard-to-diagnose bugs if not handled from day one. The MLX model (2–8 second load) and whisper model must both be pre-loaded at app launch in background Tasks — lazy loading on first use is an unacceptable UX failure.

The recommended build order follows the component dependency graph from architecture research: foundational infrastructure first (settings, model management, audio capture), then the transcription pipeline (whisper.cpp bridge with actor isolation), then LLM post-processing, then text insertion with its dual-path fallback strategy, and finally the full UI and polish. This sequencing ensures each layer is independently testable before the next is built on top of it, and that the two highest-risk integrations (C++ bridge, Accessibility API) are resolved before any dependent features are attempted.

## Key Findings

### Recommended Stack

The stack is anchored by Swift 6 with full concurrency (actors, async/await, AsyncStream) — this is required, not optional, because the audio pipeline crosses real-time threads, GPU-bound inference tasks, and UI updates. whisper.cpp 1.8.1 from `ggml-org/whisper.cpp` (direct SPM, not the deprecated `whisper.spm`) provides Metal-accelerated transcription; mlx-swift-lm 2.30.6 provides MLX-native LLM inference. Both require Xcode 16+ because Metal shaders cannot be compiled via SPM alone. KeyboardShortcuts (sindresorhus) wraps CGEventTap for user-configurable global hotkeys. All permission-sensitive APIs (AVFoundation, Accessibility, ServiceManagement) are system frameworks — no third-party dependencies needed there.

**Core technologies:**
- Swift 6 + SwiftUI (macOS 14+): Language and UI framework — actor concurrency model required for safe audio pipeline
- whisper.cpp 1.8.1 (ggml-org SPM): Transcription engine — Metal GPU acceleration on Apple Silicon, large-v3-turbo quality
- mlx-swift-lm 2.30.6: Local LLM inference — Apple's own MLX framework, Qwen3-1.7B supported, same model ecosystem as Python version
- AVFoundation / AVAudioEngine: Microphone capture — system framework, supports real-time 16kHz mono PCM tap
- Accessibility API (ApplicationServices): Text insertion at cursor — only mechanism for cursor-position insertion without clipboard disruption
- KeyboardShortcuts (sindresorhus): Global hotkeys — supports push-to-talk (onKeyDown/onKeyUp), user-configurable
- SMAppService (ServiceManagement): Login item — modern macOS 13+ API, visible in System Settings
- Accelerate framework: Audio format conversion — sample rate conversion for 16kHz resampling

**What to avoid:**
- `whisper.spm` (archived/deprecated) — use `ggml-org/whisper.cpp` directly
- `SFSpeechRecognizer` — quality for Traditional Chinese is unacceptable; requires internet
- `NSWorkspace`/pasteboard-only insertion — clobbers clipboard; use AXUIElement as primary path
- App Sandbox — incompatible with Accessibility API and global hotkeys; this is direct distribution
- Combine for audio pipeline — use Swift Concurrency (AsyncStream) instead

### Expected Features

Research confirms feature parity with the Python version as the correct v1 scope. The LLM post-processing for Traditional Chinese punctuation is the primary differentiator — competitors either skip this (Sotto) or do it via cloud APIs (Superwhisper). Local Qwen3-1.7B via MLX is a genuine competitive advantage.

**Must have (table stakes):**
- Global hotkey: toggle mode (Shift+Cmd+A) and push-to-talk (Option+Space)
- Whisper transcription with Metal GPU acceleration
- LLM post-processing (Qwen3-1.7B) for TC punctuation and formatting
- Text insertion via Accessibility API with clipboard fallback
- Menu bar app (LSUIElement) with visual recording indicator
- Model download and progress UI (first-launch experience)
- Settings: hotkey config, confirm-before-insert, debug mode, auto-start
- Auto-start at login via SMAppService
- Debug mode: save WAV + JSON per transcription

**Should have (v1.x, post-validation):**
- Confirm-before-insert overlay
- Silence detection / auto-stop VAD
- Custom vocabulary / substitution table
- Translation mode (TC to EN, native Whisper task)
- Floating transcription preview for long dictations

**Defer (v2+):**
- Context-aware insertion (reading selected text for LLM context) — high complexity
- Per-app mode profiles — significant complexity, validate demand first
- Multi-language support — TC-first is correct; expand based on user data
- Model size selection UI — add when user base diversity requires it

### Architecture Approach

The architecture is a layered pipeline with `RecordingCoordinator` (Swift actor) as the single orchestrator. All other components are passive services. The UI layer observes an `@Observable AppState` class. The critical design constraint is that no real-time thread (audio tap callback, CGEventTap callback) may ever do real work — both must dispatch to actors immediately. whisper.cpp and MLX inference must each run in their own `Task.detached` to allow parallel GPU use. Build order follows the dependency graph: SettingsStore first, then ModelManager, then AudioCapture and inference bridges independently, then RecordingCoordinator to tie them together, then UI last.

**Major components:**
1. `RecordingCoordinator` (actor) — state machine (idle/recording/transcribing/inserting), orchestrates full pipeline
2. `AudioCapture` — AVAudioEngine tap with AVAudioConverter resampling to 16kHz mono Float32
3. `WhisperBridge` (actor-isolated) — C interop wrapper for whisper.cpp, manages context lifetime, runs in Task.detached
4. `LLMPostProcessor` — MLX Swift model loading and generation, runs in Task.detached, pre-loaded at launch
5. `HotkeyMonitor` — CGEventTap with timeout re-enable handler, posts notifications only (no work in callback)
6. `TextInserter` — AXUIElementSetAttributeValue primary path, NSPasteboard+CMD+V fallback with clipboard restore
7. `ModelManager` — URLSession download, checksum verification, path resolution, progress reporting
8. `SettingsStore` — UserDefaults @AppStorage wrapper, read by all components at init

### Critical Pitfalls

1. **CGEventTap silently disabled by macOS watchdog** — The tap stops working after a few transcriptions if the callback does any real work. Fix: callback does exactly one thing (set a flag or post notification), and explicitly handles `kCGEventTapDisabledByTimeout` by calling `CGEventTapEnable(tap, true)`.

2. **Accessibility permission revoked on every Xcode rebuild** — TCC ties permission to code signature; each debug build gets a new signature. Fix: always check `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` at startup and surface a warning icon if not trusted.

3. **Audio sample rate mismatch** — AVAudioEngine delivers 44.1/48kHz; whisper.cpp requires exactly 16kHz mono Float32. Passing raw buffers produces garbage transcription. Fix: install tap with `AVAudioConverter` targeting `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)`.

4. **Whisper hallucinations on silence/short utterances** — whisper.cpp always produces output; on silence it emits random Chinese characters. Fix: implement energy-based VAD gate, set `no_speech_thold = 0.6` in whisper params, check `no_speech_prob` on every result, enforce minimum utterance duration (~0.8s), force `language = "zh"`.

5. **AX insertion silently fails in Electron apps** — `kAXSelectedTextAttribute` write returns success in VS Code/Slack/Chrome but nothing is inserted. Fix: verify element value changed within 50ms after write; fall back to clipboard paste with NSPasteboard restoration (`TransientType`). Both paths must be implemented together, not sequentially.

6. **MLX model load blocks main thread** — 2–8 second synchronous load freezes the menu bar. Fix: `Task.detached` at app launch, show "Loading model..." state in menu bar icon, disable hotkey until model is ready.

7. **whisper.cpp C++ memory safety** — `withUnsafeBufferPointer` pointers are only valid inside the closure; storing them for async use causes use-after-free. `whisper_context` is not thread-safe across concurrent calls. Fix: wrap all whisper calls in a Swift actor (`WhisperActor`) with a serial executor; never store unsafe pointers across async boundaries.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Project Foundation and Settings Infrastructure
**Rationale:** `SettingsStore` has no dependencies and is consumed by every other component. The menu bar app shell and LSUIElement configuration must exist before any other UI can be wired. Establishing the app entry point, bundle structure, and UserDefaults schema unblocks all parallel work.
**Delivers:** Compilable menu bar app that lives in the system tray, persists settings, and handles the app lifecycle correctly.
**Addresses:** Menu bar presence (table stakes), auto-start at login, settings UI scaffolding.
**Avoids:** Getting the LSUIElement + MenuBarExtra scene wrong before other features are built on it.

### Phase 2: Model Management and First-Launch Experience
**Rationale:** `ModelManager` blocks both `WhisperBridge` and `LLMPostProcessor`. Models must be downloaded and verified before any transcription is possible. First-launch UX (download progress, setup flow) must be implemented before the pipeline is built on top of it, or it becomes a retrofit.
**Delivers:** Model download, checksum verification, progress UI, and model path resolution. App is functional after first-launch model setup.
**Addresses:** Model download manager (P1 feature), first-launch experience.
**Avoids:** Pitfall 6 (lazy model load blocking main thread) — models pre-load at launch in background Tasks.

### Phase 3: Audio Capture Pipeline
**Rationale:** Audio capture is a standalone vertical slice with no dependencies on whisper or MLX. Solving the format conversion (16kHz mono Float32) correctly here, before whisper integration begins, prevents the hardest-to-debug pitfall in the project.
**Delivers:** Working AVAudioEngine tap that accumulates correctly formatted Float32 PCM buffers, ready for whisper.cpp.
**Uses:** AVFoundation, Accelerate framework.
**Implements:** `AudioCapture` component with `AVAudioConverter` resampling.
**Avoids:** Pitfall 3 (audio format mismatch — the most common source of "garbage transcription" bugs).

### Phase 4: Global Hotkey Infrastructure
**Rationale:** `HotkeyMonitor` is also standalone and must establish the CGEventTap re-enable pattern before any logic depends on the hotkey reliably firing. Testing the timeout watchdog fix in isolation (20 consecutive activations, verify tap survives) is far easier before the full pipeline exists.
**Delivers:** Reliable global hotkey that survives extended use, with push-to-talk and toggle modes, user-configurable via KeyboardShortcuts.
**Uses:** KeyboardShortcuts library, CGEventTap.
**Avoids:** Pitfall 1 (CGEventTap silently disabled by timeout) — most impactful reliability issue.

### Phase 5: whisper.cpp Transcription Bridge
**Rationale:** The C++ interop is the highest-technical-risk integration. It must be built with proper actor isolation and memory safety patterns before the pipeline coordinator is assembled. Building it in isolation allows Address Sanitizer and Thread Sanitizer runs before other complexity is layered on.
**Delivers:** `WhisperBridge` actor that accepts Float32 PCM buffers and returns transcription strings, with `no_speech_prob` filtering and VAD gate.
**Uses:** whisper.cpp 1.8.1 (ggml-org SPM), Swift actor pattern.
**Implements:** `WhisperBridge`, `WhisperContext` lifecycle management.
**Avoids:** Pitfall 4 (hallucinations on silence), Pitfall 7 (C++ memory safety). Forces language to `zh`, sets `no_speech_thold`.

### Phase 6: LLM Post-Processing
**Rationale:** MLX post-processing is independent of whisper.cpp and can be developed in parallel or sequentially. It enhances transcription output but is not required for basic insertion. Building it as a separate phase keeps the whisper integration testable without MLX complexity.
**Delivers:** `LLMPostProcessor` that takes raw whisper output and returns punctuated, formatted Traditional Chinese text using Qwen3-1.7B.
**Uses:** mlx-swift-lm 2.30.6.
**Implements:** `LLMPostProcessor`, `PromptBuilder`.
**Avoids:** Pitfall 6 (blocking main thread during model load) — pre-load in Task.detached at launch.

### Phase 7: Text Insertion
**Rationale:** Text insertion requires the most defensive implementation in the project. Both the AX primary path and the clipboard fallback must be implemented and tested simultaneously — testing in isolation against TextEdit is not sufficient. This phase must validate against VS Code, Slack, Chrome, and Terminal.
**Delivers:** `TextInserter` with AX primary path and verified clipboard fallback with NSPasteboard restoration.
**Uses:** Accessibility API, NSPasteboard.
**Avoids:** Pitfall 2 (AX permission revocation), Pitfall 5 (silent failure in Electron apps).

### Phase 8: Pipeline Integration (RecordingCoordinator)
**Rationale:** Once all service components are independently tested, `RecordingCoordinator` wires them together. This phase has the lowest individual risk because each piece is already verified — the risk is integration seams and state machine correctness.
**Delivers:** End-to-end working pipeline: hotkey → record → transcribe → format → insert. App is functionally complete.
**Implements:** `RecordingCoordinator` actor, `AppState` observable, full state machine.

### Phase 9: UI Polish and Settings Completion
**Rationale:** Full Settings UI, model download UI, visual recording indicators, confirm-before-insert overlay, and permission onboarding are deferred to this phase because they depend on the pipeline being stable.
**Delivers:** Complete user-facing experience: settings sheet, hotkey recorder UI, model download progress view, distinct menu bar icon states (idle/loading/recording/processing/error).
**Addresses:** Settings UI (P1), visual recording indicator, microphone permission onboarding, confirm-before-insert.

### Phase 10: Debug Mode, Auto-Start, and Distribution Readiness
**Rationale:** Debug mode (WAV + JSON save) and auto-start (SMAppService) are low-complexity and can be final. Distribution readiness — code signing, Sparkle updater, entitlements file — should be its own phase to avoid surprising gotchas late.
**Delivers:** Debug recording archive, login item registration, app ready for distribution.
**Avoids:** LaunchAgent stale-entry-after-update pitfall.

### Phase Ordering Rationale

- Phases 1–4 build foundational infrastructure that everything else depends on; none of them depend on each other (except Phase 2 requiring Phase 1's app shell) — Phases 3 and 4 could run in parallel.
- Phases 5–6 build the two inference bridges independently — they could also run in parallel.
- Phase 7 (text insertion) is deliberately kept separate because its dual-path fallback has the highest implementation complexity and most failure modes; isolation makes testing tractable.
- Phase 8 is integration only — its purpose is to expose any remaining seam bugs between independently verified components.
- Phases 9–10 are pure finishing work; putting them last means they never block the core pipeline being usable.

### Research Flags

Phases likely needing `/gsd:research-phase` deeper research during planning:
- **Phase 5 (whisper.cpp bridge):** SPM product name and exact Package.swift target structure confirmed at MEDIUM confidence from WebSearch; verify by reading actual Package.swift from `ggml-org/whisper.cpp` before implementation. C++ interop patterns are complex enough that a focused implementation spike is warranted.
- **Phase 6 (MLX LLM post-processing):** mlx-swift-lm API surface (specifically `LLMModelFactory` and `ChatSession` vs lower-level APIs) should be verified against the current 2.30.6 release; API may differ from older tutorials.
- **Phase 7 (text insertion):** The NSPasteboard `TransientType` pattern for clipboard managers (Raycast, Alfred) needs verification; behavior may differ across clipboard manager versions.

Phases with standard patterns (skip research-phase):
- **Phase 1 (app foundation):** SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)` is well-documented; `LSUIElement` in Info.plist is standard.
- **Phase 3 (audio capture):** AVAudioEngine + AVAudioConverter pattern is standard; 16kHz resampling is a solved problem.
- **Phase 4 (hotkeys):** KeyboardShortcuts library has excellent documentation; CGEventTap re-enable pattern is well-documented.
- **Phase 10 (auto-start):** SMAppService.mainApp is straightforward; Sparkle updater integration is standard.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All core libraries verified from official GitHub repos with confirmed versions; only whisper.cpp SPM product name is MEDIUM (WebSearch, not directly read) |
| Features | HIGH | Competitor feature analysis from multiple current sources (2025–2026); Python version provides ground truth for v1 scope |
| Architecture | HIGH | Core macOS APIs are first-party and well-documented; Swift actor patterns for C interop are established; component boundaries are clean |
| Pitfalls | MEDIUM | CGEventTap timeout, audio format, and AX permission pitfalls are verified against official docs and GitHub issues; some edge cases (clipboard manager compatibility) are inference-based |

**Overall confidence:** HIGH

### Gaps to Address

- **whisper.cpp SPM product name:** Research confirmed `whisper` as product name via WebSearch but the actual Package.swift was not directly read. Verify before writing the Package.swift dependency block.
- **mlx-swift-lm 2.30.6 API surface:** Tutorial code showing `LLMModelFactory` and `ChatSession` may reflect an older API version. Read the current source or examples before writing `LLMPostProcessor`.
- **Clipboard manager compatibility with TransientType:** NSPasteboard `TransientType` is documented and used by Raycast/Alfred to skip clipboard history, but behavior across all clipboard managers is unverified. Accept this as a best-effort mitigation and document the known limitation.
- **Option+Space hotkey conflict:** macOS does not assign Option+Space as a system shortcut by default, but some users configure it for Spotlight or language switching. Research recommends detecting this at startup; implementation detail TBD during Phase 4.

## Sources

### Primary (HIGH confidence)
- [github.com/ggml-org/whisper.cpp](https://github.com/ggml-org/whisper.cpp) — v1.8.1, Metal support, SPM integration
- [github.com/ml-explore/mlx-swift-lm](https://github.com/ml-explore/mlx-swift-lm) — v2.30.6, Qwen3 support confirmed
- [github.com/sindresorhus/KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — onKeyDown/onKeyUp, macOS 14+ compatible
- [Apple WWDC 2025 — MLX on Apple Silicon](https://developer.apple.com/videos/play/wwdc2025/298/) — Apple endorsement of MLX for on-device inference
- [Apple Developer Docs — SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice) — modern login item API
- [Apple Developer Docs — AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement) — text insertion API
- [Apple Developer Docs — CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout) — timeout handling
- Python version PROJECT.md — ground truth for v1 feature scope

### Secondary (MEDIUM confidence)
- [whisper.cpp GitHub Issues #1490](https://github.com/ggml-org/whisper.cpp/discussions/1490) — hallucination and repetition on silence
- [jano.dev — Accessibility Permission in macOS (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html) — TCC permission persistence behavior
- [nilcoalescing.com — MenuBarExtra SwiftUI](https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/) — MenuBarExtra window style pattern
- Competitor analysis: Superwhisper, Sotto, Wispr Flow official sites and comparison articles (2025–2026)
- [Deepgram — Whisper v3 Hallucinations](https://deepgram.com/learn/whisper-v3-results) — hallucination characteristics

### Tertiary (inference-based, needs validation)
- NSPasteboard TransientType behavior across clipboard managers — best-effort from nspasteboard.org documentation
- whisper.cpp SPM product name `whisper` — WebSearch confirmed, not directly read from Package.swift

---
*Research completed: 2026-03-16*
*Ready for roadmap: yes*
