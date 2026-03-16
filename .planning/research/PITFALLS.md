# Pitfalls Research

**Domain:** Native macOS voice-to-text input tool (Swift, whisper.cpp, MLX Swift, Accessibility API)
**Researched:** 2026-03-16
**Confidence:** MEDIUM (WebSearch verified against official docs and GitHub issues)

---

## Critical Pitfalls

### Pitfall 1: CGEventTap Silently Disabled by macOS Watchdog

**What goes wrong:**
The global hotkey event tap (CGEventTap) stops receiving events after a period of use, with no visible error. macOS automatically disables event taps that take too long to process callbacks — a timeout watchdog. The app appears running but hotkeys do nothing. Users have to restart the app.

**Why it happens:**
Developers put work (model loading, audio engine setup, or even Swift async bridging overhead) inside the event callback, causing it to exceed macOS's processing deadline. The `kCGEventTapDisabledByTimeout` event fires, the tap is disabled, and since no handler checks for it, nothing re-enables it. It also happens when the callback thread stalls due to Main Actor contention.

**How to avoid:**
- In the CGEventTap callback, check for `type == .tapDisabledByTimeout` and immediately call `CGEventTapEnable(tap, true)`.
- The callback must do exactly one thing: post a notification or set a flag. Dispatch all real work off the callback thread.
- Keep the callback under 1ms of CPU time. No I/O, no Locks, no Swift async calls.

**Warning signs:**
- Hotkey works after fresh launch but stops working after a few transcriptions.
- Adding a print statement to the callback shows it stops being called.
- Restarting the app restores hotkey functionality.

**Phase to address:** Hotkey infrastructure phase (early, before any other feature depends on it).

---

### Pitfall 2: Accessibility Permission Not Persisted Across App Rebuilds / Code Signing Changes

**What goes wrong:**
macOS TCC ties Accessibility permission grants to the app's code signature. Every time Xcode rebuilds with a new signature (common during development with automatic signing), or if the bundle identifier or team ID changes, the app's Accessibility permission is silently revoked. The app shows as trusted in System Settings, but `AXIsProcessTrusted()` returns `false`. Text insertion silently fails — no error, no prompt.

**Why it happens:**
TCC matches by bundle ID + code signature hash. Debug builds often have a different signature from each build. Apple does not re-prompt users; the old entry simply becomes invalid.

**How to avoid:**
- Use a consistent provisioning profile during development or use `--deepens` to match signatures.
- Always check `AXIsProcessTrusted()` at startup and surface the result in the menu bar UI (e.g., a warning icon).
- On startup, call `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` to prompt the user if not trusted.
- Test permission flows in a clean user account regularly.

**Warning signs:**
- Text insertion does nothing after a rebuild.
- `AXIsProcessTrusted()` returns `false` but System Settings shows the app as enabled.
- No error from `AXUIElementSetAttributeValue`.

**Phase to address:** Text insertion phase. Must be the first thing verified before building any insertion logic.

---

### Pitfall 3: Audio Format Mismatch — whisper.cpp Requires 16kHz Mono Float32, AVAudioEngine Delivers 32kHz or 48kHz Interleaved

**What goes wrong:**
`AVAudioEngine` records at the hardware's native sample rate (typically 44.1kHz or 48kHz on Apple Silicon Macs) in the `inputNode`'s native format. Passing this buffer directly to whisper.cpp produces garbage transcription (wrong pitch interpretation) or a silent crash because the C API receives a buffer of the wrong length.

**Why it happens:**
Developers install a tap on `AVAudioEngine.inputNode` and pass the raw `AVAudioPCMBuffer` samples directly to whisper.cpp's `whisper_pcm_to_mel` or equivalent. The sample count is correct but the sample rate is not 16kHz. whisper.cpp does not resample internally.

**How to avoid:**
- Install the tap with an explicit converter: use `AVAudioConverter` to resample to `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)` before accumulating samples.
- Verify format at runtime: assert that the buffer passed to whisper has exactly `16000` samples per second.
- Accumulate a full utterance's worth of float32 samples before sending to whisper — do not send individual tap callbacks.

**Warning signs:**
- Transcription produces phonetically wrong output (sped-up or slowed-down sounding words).
- No crash but output is gibberish for all input.
- Model latency seems lower than expected (fewer samples than whisper expects).

**Phase to address:** Audio capture phase, before whisper.cpp integration begins.

---

### Pitfall 4: whisper.cpp Hallucinations on Silence / Short Utterances for Chinese

**What goes wrong:**
whisper.cpp (including large-v3-turbo) hallucinates text when given silence, ambient noise, or very short utterances (under 1 second). For Chinese specifically, it may emit repeated characters, English words, or complete gibberish when no speech is detected. This text then gets inserted at the cursor.

**Why it happens:**
Whisper is a sequence-to-sequence model trained to always produce output. The large-v3 family has known hallucination issues on silence/noise, and the turbo variant with reduced decoder layers can amplify this. Chinese and Traditional Chinese specifically have less training data than English, making the model more likely to "fill in" when uncertain.

**How to avoid:**
- Implement a voice activity detection (VAD) gate before sending audio to whisper. Only transcribe if audio energy exceeds a threshold for at least N milliseconds.
- Set `no_speech_thold` in whisper.cpp params (typically 0.6) to suppress low-confidence outputs.
- Implement minimum utterance duration (discard recordings under ~0.8 seconds).
- Always check the `no_speech_prob` field in the whisper result and suppress insertion if it exceeds the threshold.
- In Traditional Chinese mode, force `language = "zh"` in whisper params — never let it auto-detect.

**Warning signs:**
- Random Chinese characters appear when user activates hotkey without speaking.
- Transcription consistently produces the same repeated character on silence.
- Output contains English words in an otherwise Chinese transcription.

**Phase to address:** whisper.cpp integration phase. VAD and silence detection must ship with the initial transcription feature.

---

### Pitfall 5: Text Insertion via Accessibility API Silently Fails on Non-Standard Apps

**What goes wrong:**
`AXUIElementSetAttributeValue(focusedElement, kAXSelectedTextAttribute, text)` works in most Cocoa apps but silently does nothing in Electron apps (VS Code, Slack, Discord), Terminal, many web browsers, and some sandboxed apps. The API call returns success (`kAXErrorSuccess`) but no text is inserted. The clipboard fallback is then triggered too late or not at all.

**Why it happens:**
The Accessibility text-insert API depends on apps exposing correct AX roles. Electron wraps Chromium's own accessibility tree which does not reliably support `kAXSelectedTextAttribute` writes. The API returns success even when the app ignores the write.

**How to avoid:**
- Never rely solely on the Accessibility API path. The clipboard fallback (save clipboard, write text, CMD+V, restore clipboard) must be the universal fallback.
- After Accessibility insertion, verify insertion by checking if the focused element's value changed. If verification fails within 50ms, fall back to clipboard paste.
- The clipboard restore must use `NSPasteboard.TransientType` to mark content as temporary, so clipboard managers (Raycast, Alfred) don't treat it as user-copied content.
- Add a configurable delay (default 100ms) between writing to clipboard and sending CMD+V, to account for slow focus transitions.

**Warning signs:**
- Text insertion works in TextEdit but not VS Code or Slack.
- AX API returns `kAXErrorSuccess` but text is not inserted.
- Users report missing text in terminal or browser address bars.

**Phase to address:** Text insertion phase. Both insertion paths (AX API and clipboard) must be implemented and tested together, not sequentially.

---

### Pitfall 6: MLX Swift Model Loading Blocks the Main Thread

**What goes wrong:**
Loading Qwen3-1.7B via MLX Swift takes 2–8 seconds on first load (reading weights from disk, quantizing, allocating GPU memory). If this is called synchronously on the main thread or in response to a UI event, the menu bar app freezes, the menu does not open, and macOS may show the spinning beachball.

**Why it happens:**
Developers call the MLX model load function in `applicationDidFinishLaunching` or in response to the first transcription request without dispatching to a background Task. MLX Swift's model loading APIs are not async by default in all codepaths.

**How to avoid:**
- Always load models in a `Task { await ... }` with explicit `Task.detached` to avoid inheriting Main Actor context.
- Show a loading state in the menu bar icon (e.g., animated icon or "Loading model..." menu item) while the model is being loaded.
- Pre-load models at app launch in the background — do not lazy-load on first use (which causes a freeze at the worst moment, mid-recording).
- Load whisper.cpp model and MLX model concurrently using `async let`.

**Warning signs:**
- Menu bar icon is unresponsive for several seconds after launch.
- App freezes when user activates hotkey for the first time.
- Xcode thread performance gauge shows main thread at 100% during model load.

**Phase to address:** Model management phase (dedicated phase before end-to-end pipeline integration).

---

### Pitfall 7: whisper.cpp C++ Bridging — Memory Management and Thread Safety

**What goes wrong:**
whisper.cpp is a C++ library. Bridging it to Swift requires a C wrapper header, manual memory management for `whisper_context`, and careful lifetime management of audio buffers passed across the ABI boundary. Common mistakes: freeing the context while inference is running, passing a Swift Array's buffer pointer outside the `withUnsafeBufferPointer` closure, or running `whisper_full` on the main thread.

**Why it happens:**
Swift developers are unfamiliar with C++ interop nuances. Swift's `withUnsafeBufferPointer` provides a temporary pointer that is only valid within the closure — storing it and passing it to an async operation causes a use-after-free. The `whisper_context` is not thread-safe across concurrent calls.

**How to avoid:**
- Wrap all whisper.cpp calls in a single serial `DispatchQueue` or Swift Actor (`WhisperActor`) to enforce single-threaded access.
- Never store pointers from `withUnsafeBufferPointer` beyond the closure. Copy data to a C-allocated buffer (via `malloc`) if it must outlive the Swift array.
- Use a Swift wrapper class that owns the `whisper_context` and implements `deinit` to call `whisper_free`.
- Consider using the `whisper.spm` Swift Package (github.com/ggerganov/whisper.spm) to avoid writing the C bridge manually.

**Warning signs:**
- Intermittent crashes in `whisper_full` with EXC_BAD_ACCESS.
- Crashes only occur on second or subsequent transcriptions.
- Thread Sanitizer reports data races in the whisper bridge code.

**Phase to address:** whisper.cpp integration phase. The Actor-based wrapper must be designed before any transcription logic is written.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Skip clipboard restore after paste | Simpler insertion code | User's clipboard is wiped after every transcription — severe UX breakage | Never |
| Lazy model load on first hotkey | Faster launch time | Frozen UI on first use — users think app is broken | Never |
| Run whisper on main thread | Simpler code | Audio tap callbacks block, app freezes during transcription | Never |
| Skip VAD, always transcribe | Simpler pipeline | Hallucinations inserted on silence, user loses trust quickly | Never |
| Force-language to "zh" hardcoded | Simpler code | Cannot support other languages later, brittle | Acceptable for v1 |
| Skip AX insertion verification | Faster insertion path | Silent failures in Electron/browser apps | Never |
| Single NSPasteboard.general write without restoration | Simple clipboard code | Destroys user clipboard contents | Never |

---

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| whisper.cpp | Passing 44.1kHz PCM directly | Convert to 16kHz mono Float32 with AVAudioConverter before passing |
| whisper.cpp | Not setting `language = "zh"` | Always force language for Traditional Chinese to avoid auto-detect switching to Japanese or English |
| MLX Swift | Loading model synchronously | Load in detached Task at app launch, surface loading state in menu bar |
| CGEventTap | Not handling `.tapDisabledByTimeout` | Check for timeout event in callback, call `CGEventTapEnable` to re-enable |
| AXUIElement | Assuming success means insertion succeeded | Verify element value changed post-write; fall back to clipboard if not |
| NSPasteboard | Writing to general pasteboard without restore | Save existing contents, mark with `TransientType`, restore after CMD+V |
| AVAudioEngine | Using inputNode directly without format conversion | Install tap with explicit `AVAudioConverter` targeting 16kHz mono Float32 |
| LaunchAgent | Hardcoding absolute paths in plist | Use `$(HOME)` expansion or discover bundle path at install time |

---

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Accumulating raw 48kHz audio then converting | Conversion happens after recording stops, adds perceptible delay | Convert incrementally during recording via streaming AVAudioConverter | Every transcription |
| Blocking main thread for AX element lookup | Menu bar unresponsive during text insertion | Move AX calls to a background queue, only dispatch CMD+V key event on main | Every insertion |
| Re-loading MLX model on every transcription | 3–8 second freeze per use | Load once at launch, keep model resident in memory | First use after each transcription |
| Sending full recording audio to whisper (unbounded) | Very long recordings exhaust memory | Cap recording at a configurable max (e.g., 60 seconds); warn user near limit | Recordings over ~30 seconds |
| MLX KV cache growing unbounded across LLM calls | Memory grows session after session | Reset KV cache between unrelated transcription/formatting calls | After ~50+ uses in one session |

---

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No feedback during 2–5 second transcription | User thinks app froze; presses hotkey again, double-activates | Show visual indicator in menu bar icon (e.g., animated waveform or spinner) |
| Inserting text with clipboard without restoring it | User's clipboard is wiped silently after every dictation | Always save, use `TransientType`, and restore NSPasteboard contents |
| Requesting Accessibility permission without explanation | Users deny the scary permission dialog | Show pre-permission explanation screen describing exactly why access is needed |
| Hotkey conflicts with system shortcuts (Option+Space = Spotlight in some configs) | Hotkey silently captured by system, app never fires | Detect conflict at startup, warn user, suggest alternatives |
| No confirmation-before-insert option | Transcription errors go directly into documents | Ship "confirm before insert" mode from day one; this is already in requirements |
| Menu bar icon looks identical whether loading model, recording, or idle | User cannot tell what state the app is in | Use distinct icon states: idle, loading, recording, processing, error |

---

## "Looks Done But Isn't" Checklist

- [ ] **Global hotkey:** Works after Accessibility permission is freshly granted but does NOT yet verify behavior survives app rebuild/re-sign — test with fresh TCC database.
- [ ] **Text insertion:** Works in TextEdit and Notes — verify in VS Code, Slack, Chrome address bar, and Terminal before declaring done.
- [ ] **Clipboard fallback:** Paste works — verify clipboard contents are fully restored after insertion, including rich text types, not just plain string.
- [ ] **Transcription pipeline:** Returns text — verify `no_speech_prob` check is active and silence/short audio does not produce hallucinated output.
- [ ] **Model loading:** App launches — verify loading state is visible in menu bar and hotkey is properly disabled until model is ready.
- [ ] **CGEventTap:** Hotkey works at launch — verify it still works after 10 consecutive transcriptions (timeout watchdog test).
- [ ] **LaunchAgent:** Auto-start works — verify it survives an update/reinstall and that the old LaunchAgent is unloaded before installing a new one.
- [ ] **Microphone permission:** Granted once — verify behavior when user revokes microphone access mid-session (should show clear error, not crash).

---

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| CGEventTap disabled silently | LOW | Add `.tapDisabledByTimeout` handler and re-enable call; no architecture change needed |
| AX permission revocation on rebuild | LOW | Add startup trust check with `AXIsProcessTrustedWithOptions`; surface in UI |
| Audio format mismatch (wrong sample rate to whisper) | MEDIUM | Introduce `AVAudioConverter` layer between tap and whisper; requires refactor of audio buffer accumulation |
| Hallucinations on silence | MEDIUM | Add VAD energy gate and `no_speech_prob` check; requires pipeline changes |
| MLX model load blocking main thread | MEDIUM | Wrap load in `Task.detached`, add loading state management, update UI to show state |
| AX insertion silent failure without fallback | HIGH | Implement dual-path insertion with verification and clipboard fallback; significant new code |
| C++ memory corruption in whisper bridge | HIGH | Refactor all whisper calls behind a Swift Actor; audit all buffer pointer lifetimes |

---

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| CGEventTap disabled by timeout | Hotkey infrastructure | Run 20 consecutive hotkey activations; verify tap still fires |
| AX permission revocation on rebuild | Text insertion setup | Test with freshly reset TCC (`tccutil reset Accessibility`); verify prompt appears |
| Audio format mismatch (16kHz) | Audio capture | Assert sample rate of buffer passed to whisper is exactly 16000 in debug builds |
| Whisper hallucinations on silence | whisper.cpp integration | Send 2 seconds of silence; verify no text is inserted |
| AX insertion silent failure in Electron | Text insertion | Integration test against VS Code, Slack, Chrome; verify clipboard fallback triggers |
| Clipboard not restored after paste | Text insertion | Verify clipboard contents before and after insertion are identical |
| MLX model load on main thread | Model management | Profile with Instruments Time Profiler; main thread must be idle during model load |
| whisper.cpp C++ memory safety | whisper.cpp integration | Run Thread Sanitizer and Address Sanitizer for 10 consecutive transcriptions |
| Hotkey conflict (Option+Space) | Hotkey infrastructure | Test on clean macOS install with default system shortcuts |
| LaunchAgent stale entry after update | Auto-start / distribution | Simulate update: install v1, install v2, verify only v2 agent is loaded |

---

## Sources

- whisper.cpp GitHub Issues: [Hallucination and repetition discussion #1490](https://github.com/ggml-org/whisper.cpp/discussions/1490)
- whisper.cpp GitHub Issues: [16kHz sample rate requirement #909](https://github.com/ggml-org/whisper.cpp/issues/909)
- Apple Developer Forums: [CGEventTap timeout handling](https://developer.apple.com/forums/thread/735223)
- AeroSpace Issue: [CGEvent.tapCreate reliability investigation](https://github.com/nikitabobko/AeroSpace/issues/1012)
- Apple Developer Documentation: [CGEventType.tapDisabledByTimeout](https://developer.apple.com/documentation/coregraphics/cgeventtype/tapdisabledbytimeout)
- Apple Developer Documentation: [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement)
- Accessibility permission persistence: [jano.dev — Accessibility Permission in macOS (2025)](https://jano.dev/apple/macos/swift/2025/01/08/Accessibility-Permission.html)
- Swift text insertion patterns: [Level Up Coding — Insert Text to Other Active Applications](https://levelup.gitconnected.com/swift-macos-insert-text-to-other-active-applications-two-ways-9e2d712ae293)
- NSPasteboard transient type: [nspasteboard.org — Transient or Special Data](https://nspasteboard.org/)
- MLX Swift LLM guide: [Oneboard — Running LLMs Locally in Swift with MLX](https://oneboard.framer.website/blog/running-llms-locally-in-swift-with-mlx-a-developer-s-guide)
- macOS menu bar lessons: [Medium — What I Learned Building a Native macOS Menu Bar App (Jan 2026)](https://medium.com/@p_anhphong/what-i-learned-building-a-native-macos-menu-bar-app-eacbc16c2e14)
- AVAudioEngine mono recording: [Medium — Enhancing Audio Recording: Mono Mode](https://medium.com/@bilalbakhrom/enhancing-audio-recording-mastery-part-i-mono-mode-895f9d8747e1)
- Whisper hallucinations analysis: [Deepgram — Whisper v3 Hallucinations on Real World Data](https://deepgram.com/learn/whisper-v3-results)

---

*Pitfalls research for: native macOS voice-to-text input (Swift, whisper.cpp, MLX Swift, Accessibility API)*
*Researched: 2026-03-16*
