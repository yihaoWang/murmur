# Phase 2: Audio Capture and Transcription - Research

**Researched:** 2026-03-16
**Domain:** AVAudioEngine microphone capture + whisper.cpp Swift integration + VAD gating
**Confidence:** MEDIUM-HIGH (core patterns verified; SPM product name has one key caveat noted below)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUDIO-01 | Record microphone audio at 16kHz mono Float32 PCM | AVAudioEngine + AVAudioConverter pattern verified; hardware always captures at native rate (~44.1kHz), must convert |
| AUDIO-02 | Request microphone permission on first use with clear explanation | AVCaptureDevice.requestAccess(for: .audio) + NSMicrophoneUsageDescription in Info.plist |
| AUDIO-03 | Audio capture starts/stops in response to hotkey events with <100ms latency | AVAudioEngine installTap/removeTap is synchronous; start/stop is well under 100ms; integrate via NotificationCenter from HotkeyMonitor |
| STT-01 | Transcribe audio using whisper.cpp with Metal GPU acceleration | SwiftWhisper SPM wraps whisper.cpp; Metal runs automatically on Apple Silicon; CoreML encoder needed for ANE path |
| STT-02 | Download whisper large-v3-turbo model on first launch with progress indicator | ModelManager already has skeleton; HuggingFace URL confirmed; URLSession download delegate pattern already in place |
| STT-03 | Apply VAD gating to prevent hallucinated output on silence/noise | Energy-based RMS threshold gate before calling whisper; minimum ~0.5–1s of audio above threshold required |
</phase_requirements>

---

## Summary

Phase 2 wires together two independent pipelines: (1) microphone capture via AVAudioEngine that feeds resampled 16kHz mono Float32 PCM into an accumulation buffer, and (2) whisper.cpp inference via SwiftWhisper that consumes that buffer when recording stops. The two pipelines are decoupled by design — capture runs on an audio thread, inference runs on a background Task — connected only via the PCM buffer hand-off.

The critical technical decision already made (STATE.md) is whisper.cpp over Apple Speech. The SwiftWhisper SPM package (`https://github.com/exPHAT/SwiftWhisper.git`) is the cleanest integration path: it exposes a single `async throws` `transcribe(audioFrames:)` API that accepts a `[Float]` at 16kHz and returns segments. The whisper.spm repo (ggerganov/whisper.spm) is officially deprecated in favour of using the main ggml-org/whisper.cpp repo directly, but SwiftWhisper remains maintained and is the simplest path for an SPM app.

Metal GPU acceleration runs automatically on Apple Silicon when using whisper.cpp — no extra flag needed at the Swift call site. The existing `ModelManager` already scaffolds the download and file-path logic; Phase 2 merely needs to implement the actual inference and permission-check calls.

**Primary recommendation:** Use SwiftWhisper (product name `"SwiftWhisper"`) via SPM, capture with `AVAudioEngine.inputNode.installTap`, convert with `AVAudioConverter` to 16kHz mono Float32, gate with RMS energy check before calling `whisper.transcribe`, and drive start/stop from the existing `NotificationCenter` hotkey events.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftWhisper | branch: master | Swift wrapper around whisper.cpp; `transcribe(audioFrames:)` async API | Only maintained Swift-native SPM wrapper for whisper.cpp; abstracts C header bridging |
| AVFoundation (AVAudioEngine) | macOS 14+ (built-in) | Microphone capture via installTap; Float32 PCM access | Apple-native; lowest latency path; no extra dependency |
| AVFoundation (AVAudioConverter) | macOS 14+ (built-in) | Resample from hardware rate (44.1kHz) to 16kHz mono | Official Apple-documented resampling path for AVAudioEngine taps |
| AVFoundation (AVCaptureDevice) | macOS 14+ (built-in) | Microphone permission check and request | Correct macOS API; AVAudioSession.requestRecordPermission is iOS-centric |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Accelerate (vDSP) | built-in | Fast RMS calculation over Float arrays | Use for VAD energy computation — avoids manual loop over large buffers |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| SwiftWhisper | Direct ggml-org/whisper.cpp SPM (main repo) | Main repo Package.swift product name is unverified; requires bridging header setup; higher risk |
| SwiftWhisper | WhisperKit (argmaxinc) | WhisperKit is higher-level and well-maintained but pulls in CoreML model pipeline that differs from the gguf/ggml approach used by whisper.cpp; heavier dependency |
| AVAudioConverter | CoreAudio AudioConverter | Lower-level, more boilerplate; AVAudioConverter is sufficient and well-documented |
| Energy VAD | Silero VAD ONNX | Silero is more accurate but requires ONNX runtime dependency; energy VAD is sufficient for the dictation use case where user deliberately speaks |

**Installation — add to Package.swift:**
```swift
.package(url: "https://github.com/exPHAT/SwiftWhisper.git", branch: "master"),
```
And in target dependencies:
```swift
.product(name: "SwiftWhisper", package: "SwiftWhisper"),
```

---

## Architecture Patterns

### Recommended Project Structure

```
Typeness/
├── Core/
│   ├── AppState.swift          # EXISTING — add .recording, .transcribing states
│   ├── ModelManager.swift      # EXISTING — implement downloadWhisperModelIfNeeded fully
│   ├── AudioCaptureEngine.swift # NEW — AVAudioEngine wrapper, produces [Float] at 16kHz
│   └── TranscriptionEngine.swift # NEW — SwiftWhisper wrapper, actor, consumes [Float]
├── Input/
│   └── HotkeyMonitor.swift     # EXISTING — NotificationCenter posts already wired
└── App/
    └── TypenessApp.swift       # EXISTING — wire AudioCaptureEngine + TranscriptionEngine
```

### Pattern 1: Audio Capture with Format Conversion

AVAudioEngine's `inputNode` always operates at the hardware's native sample rate (typically 44,100 Hz, stereo or mono depending on device). You CANNOT request 16kHz directly from `installTap` — the format argument is informational only and the tap delivers at the input node's native format. Use `AVAudioConverter` in the tap callback to produce 16kHz mono Float32.

**What:** Install a tap on `engine.inputNode`, convert each buffer to 16kHz mono Float32 in the callback, append Float samples to an accumulation array.
**When to use:** Always — this is the only correct path for getting PCM into whisper.cpp.

```swift
// Source: Apple Developer Documentation (AVAudioConverter) + community pattern
import AVFoundation
import Accelerate

actor AudioCaptureEngine {
    private let engine = AVAudioEngine()
    private var samples: [Float] = []
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    func start() throws {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterCreationFailed
        }
        converter = conv
        samples.removeAll()

        // Buffer size ~100ms at native rate
        let bufferSize = AVAudioFrameCount(inputFormat.sampleRate * 0.1)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) {
            [weak self] buffer, _ in
            Task { await self?.process(buffer: buffer) }
        }
        try engine.start()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter, let inputChannelData = buffer.floatChannelData else { return }
        let frameCount = AVAudioFrameCount(
            Double(buffer.frameLength) * (16_000.0 / buffer.format.sampleRate)
        )
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: targetFormat,
            frameCapacity: frameCount + 16  // small headroom
        ) else { return }

        var error: NSError?
        var filled = false
        converter.convert(to: outBuffer, error: &error) { _, status in
            if filled { status.pointee = .noDataNow; return nil }
            filled = true
            status.pointee = .haveData
            return buffer
        }
        if let data = outBuffer.floatChannelData?[0] {
            samples.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(outBuffer.frameLength)))
        }
    }

    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return samples
    }
}
```

**Critical gotcha:** `AVAudioConverter.convert(to:error:inputBlock:)` — the `inputBlock` closure is called synchronously and will be called multiple times if the ratio requires it. The `filled` flag pattern above prevents feeding the same source buffer twice, which causes distortion.

### Pattern 2: Microphone Permission Check (macOS)

On macOS 14, use `AVCaptureDevice` for microphone permission. `AVAudioSession` is the iOS counterpart and while nominally available on macOS it is not the recommended path.

```swift
// Source: Apple Developer Documentation - Requesting Authorization for Media Capture on macOS
import AVFoundation

func checkMicrophonePermission() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .audio) {
    case .authorized:
        return true
    case .notDetermined:
        return await AVCaptureDevice.requestAccess(for: .audio)
    case .denied, .restricted:
        return false
    @unknown default:
        return false
    }
}
```

Info.plist MUST contain `NSMicrophoneUsageDescription`. Without it the system silently returns zeros for all audio data — no crash, no error, just silence.

### Pattern 3: Transcription with SwiftWhisper

```swift
// Source: SwiftWhisper README (github.com/exPHAT/SwiftWhisper)
import SwiftWhisper

actor TranscriptionEngine {
    private var whisper: Whisper?

    func load(modelURL: URL) {
        whisper = Whisper(fromFileURL: modelURL)
        // Set language to "zh" for Traditional Chinese
        // whisper.cpp uses "zh" for all Chinese variants;
        // large-v3-turbo tends to output Traditional Chinese for TC speech
        whisper?.params.language = WhisperLanguage(rawValue: "zh")
    }

    func transcribe(audioFrames: [Float]) async throws -> String {
        guard let whisper else { throw TranscriptionError.notLoaded }
        guard !audioFrames.isEmpty else { return "" }
        let segments = try await whisper.transcribe(audioFrames: audioFrames)
        return segments.map(\.text).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

**Note on SwiftWhisper params API:** The `whisper.params` property exposes `whisper_full_params` from the C API. The exact Swift property names need to be verified against the current SwiftWhisper source at implementation time — `whisper.params.language` may be a `String` or a custom type.

### Pattern 4: Energy-Based VAD Gate

Apply before calling `transcribe`. This prevents whisper.cpp from hallucinating text on silence (a well-known issue with the model when fed quiet/noise-only audio).

```swift
// Source: standard DSP pattern; vDSP verified via Apple Accelerate docs
import Accelerate

func hasVoiceActivity(samples: [Float], threshold: Float = 0.01) -> Bool {
    guard samples.count > Int(16_000 * 0.5) else { return false }  // require >= 0.5s
    var rms: Float = 0
    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
    return rms > threshold
}
```

Threshold of 0.01 (normalized Float32) corresponds roughly to -40 dB RMS, which captures quiet speech while rejecting near-silence. Tune empirically. For recordings shorter than 0.5 seconds, discard entirely — whisper hallucinates on very short clips.

### Pattern 5: Hotkey-to-Capture Integration

HotkeyMonitor (Phase 1) already posts `NotificationCenter` notifications. Wire AudioCaptureEngine to these in TypenessApp or a new `RecordingCoordinator`:

```swift
// In TypenessApp or a new RecordingCoordinator
NotificationCenter.default.addObserver(
    forName: .hotkeyToggleFired,
    object: nil,
    queue: .main
) { _ in
    Task {
        if appState.recordingState == .idle {
            await audioEngine.start()
            appState.recordingState = .recording
        } else {
            let frames = await audioEngine.stop()
            appState.recordingState = .transcribing
            let text = await transcribe(frames: frames)
            // Phase 3 will insert text; Phase 2 just prints/logs
        }
    }
}
```

The <100ms start latency requirement is met because `AVAudioEngine.start()` is near-instantaneous and `installTap` is synchronous — total overhead is well under 100ms.

### Anti-Patterns to Avoid

- **Installing the tap with `targetFormat` directly:** Passing `targetFormat` (16kHz) as the tap format does NOT resample. The system ignores it or produces corrupted audio. Always tap at the input node's native format and convert separately.
- **Calling `transcribe` on the main actor:** Whisper inference is CPU/GPU-intensive (~1–3 seconds for large-v3-turbo). Always run in an `actor` or a background `Task`.
- **Not checking VAD before transcribe:** Without the gate, whisper.cpp will hallucinate text (often Chinese characters or repeated phrases) when given silence. The gate is not optional.
- **Accumulating unbounded samples:** For a dictation app, cap accumulation at ~30 seconds (480,000 frames at 16kHz). Beyond that, whisper's context window is exceeded anyway.
- **Missing NSMicrophoneUsageDescription:** App gets zeros silently. Add this to Info.plist with a clear explanation before any permission request call.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Whisper C API bridging | Custom bridging header + manual whisper_full_params setup | SwiftWhisper | Bridging is ~500 lines of error-prone C-interop; threading and memory management are subtle |
| Audio resampling algorithm | Custom FIR/polyphase filter | AVAudioConverter | Apple's implementation handles all edge cases (non-integer ratios, channel mixing, buffer alignment) |
| Model download with progress | Custom URLSession subclass | URLSession download task + delegate (already in ModelManager) | `URLSessionDownloadDelegate.didWriteData` gives byte-level progress; already scaffolded |
| Metal GPU routing | Manual Metal compute pipeline | whisper.cpp's built-in Metal backend (auto-detected) | whisper.cpp auto-initializes Metal on Apple Silicon when linked; no configuration needed |

**Key insight:** The C-to-Swift boundary for whisper.cpp is the highest-risk area. SwiftWhisper eliminates this entirely at the cost of being locked to a community wrapper's update cadence.

---

## Common Pitfalls

### Pitfall 1: AVAudioConverter inputBlock called multiple times
**What goes wrong:** The conversion callback is called N times per `convert(to:error:inputBlock:)` call when the ratio is non-integer (e.g. 44100→16000 = 2.75625x). If you return the same buffer each call, audio is duplicated and corrupted.
**Why it happens:** The converter requests as many input buffers as needed to fill the output buffer.
**How to avoid:** Use the `filled` boolean flag pattern shown above. Return `nil` with status `.noDataNow` after the first buffer is consumed.
**Warning signs:** Distorted/sped-up audio; RMS values look wrong.

### Pitfall 2: Whisper hallucination on silence
**What goes wrong:** whisper.cpp produces plausible-sounding text (often repeated phrases or random TC characters) when given silence or background noise.
**Why it happens:** The model was trained to always produce output; it finds patterns in noise.
**How to avoid:** Energy VAD gate — compute RMS, discard if below threshold. Also enforce minimum duration (0.5s).
**Warning signs:** Text appears after hotkey press+immediate release with no speech.

### Pitfall 3: SPM build with whisper.spm fails due to unsafe build flags
**What goes wrong:** Xcode SPM resolution fails with "unsafe build flags" error when using a pinned version.
**Why it happens:** whisper.spm uses custom linker/compiler flags that SPM only allows on `branch`-tracked dependencies.
**How to avoid:** For whisper.spm, always use `branch: "master"`. For SwiftWhisper, the same applies.
**Warning signs:** Immediate SPM resolution error in Xcode, not a compile error.

### Pitfall 4: `whisper.cpp` SPM product name mismatch (KEY BLOCKER from STATE.md)
**What goes wrong:** Using `ggml-org/whisper.cpp` directly as an SPM dependency — the product name in its `Package.swift` is NOT `"whisper.cpp"` and NOT `"Whisper"` — exact name requires inspection of the repo's Package.swift at the time of implementation.
**Why it happens:** The main repo's Package.swift is not widely documented and changes between releases.
**How to avoid:** Use SwiftWhisper instead (product name `"SwiftWhisper"` is confirmed). If forced to use the main repo, read its Package.swift before writing the dependency declaration.
**Warning signs:** SPM error "no product 'X' in package 'whisper.cpp'".

### Pitfall 5: Microphone permission returning zeros silently
**What goes wrong:** `installTap` callback fires normally, audio buffers arrive, but all float values are 0.0.
**Why it happens:** Either `NSMicrophoneUsageDescription` is missing from Info.plist, or the user denied permission and the app didn't check before starting.
**How to avoid:** Call `AVCaptureDevice.authorizationStatus(for: .audio)` before starting the engine. If `.denied`, show Settings deep-link. If `.notDetermined`, call `requestAccess(for: .audio)` and await result.
**Warning signs:** RMS always 0.0; transcription returns empty string or hallucination.

### Pitfall 6: AVAudioEngine fails to start when headphones disconnected mid-session
**What goes wrong:** `engine.start()` throws or the tap stops delivering buffers when the default audio device changes (e.g., AirPods connect/disconnect).
**Why it happens:** AVAudioEngine binds to the system default input device at `start()` time.
**How to avoid:** Observe `AVAudioEngineConfigurationChangeNotification`. When received, stop, reset, and restart the engine.
**Warning signs:** Silent failure after device change; no crash but no audio.

---

## Code Examples

### Full AVAudioConverter resample pattern (verified approach)

```swift
// Source: Apple TN3136 pattern + community verification
// Key: tap at input format, convert separately
let inputNode = engine.inputNode
let inputFormat = inputNode.outputFormat(forBus: 0)  // hardware rate, e.g. 44100 Float32
let targetFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: 16_000, channels: 1, interleaved: false)!
let converter = AVAudioConverter(from: inputFormat, to: targetFormat)!

inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { buffer, _ in
    let capacity = AVAudioFrameCount(Double(buffer.frameLength) * 16_000.0 / inputFormat.sampleRate)
    let outBuf = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity + 16)!
    var used = false
    converter.convert(to: outBuf, error: nil) { _, status in
        if used { status.pointee = .noDataNow; return nil }
        used = true
        status.pointee = .haveData
        return buffer
    }
    // outBuf.floatChannelData![0] now has 16kHz mono Float32 frames
}
```

### SwiftWhisper initialization and transcription

```swift
// Source: SwiftWhisper README (github.com/exPHAT/SwiftWhisper)
import SwiftWhisper

let modelURL = /* ModelManager.whisperModelPath() */
let whisper = Whisper(fromFileURL: modelURL)
// whisper.params.language = ... // configure for "zh" if available

let segments = try await whisper.transcribe(audioFrames: floatArray16kHz)
let text = segments.map(\.text).joined()
```

### VAD gate using vDSP

```swift
// Source: Apple Accelerate vDSP documentation
import Accelerate

func meetsVADThreshold(_ samples: [Float]) -> Bool {
    let minFrames = Int(16_000 * 0.5)    // 0.5 seconds minimum
    guard samples.count >= minFrames else { return false }
    var rms: Float = 0.0
    vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
    return rms > 0.01  // ~-40 dBFS; tune in practice
}
```

### Microphone permission (macOS-correct path)

```swift
// Source: Apple Developer Documentation - Requesting Authorization for Media Capture on macOS
import AVFoundation

func requestMicrophonePermissionIfNeeded() async -> Bool {
    let status = AVCaptureDevice.authorizationStatus(for: .audio)
    switch status {
    case .authorized: return true
    case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
    default: return false
    }
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| AVAudioRecorder for capture | AVAudioEngine + installTap | macOS 10.10+ | Direct PCM buffer access; no intermediate file; lower latency |
| whisper.spm (ggerganov/whisper.spm) | Deprecated — use SwiftWhisper or main repo | 2024 (archived notice) | Must not add new dependencies on whisper.spm |
| AVAudioSession for macOS mic permission | AVCaptureDevice.requestAccess(for: .audio) | macOS 14 | AVAudioSession is iOS-primary; AVCaptureDevice is correct macOS API |
| CoreML-only acceleration | Metal backend auto-detected by whisper.cpp | whisper.cpp ~v1.5 | Metal runs automatically; CoreML encoder only needed for ANE (Neural Engine) path |

**Deprecated/outdated:**
- `ggerganov/whisper.spm`: Officially archived; README says to migrate to main repo or SwiftWhisper.
- `AVAudioSession.requestRecordPermission` on macOS: Still works but is iOS-primary; use `AVCaptureDevice` on macOS 14+.

---

## Open Questions

1. **SwiftWhisper `params.language` Swift API shape**
   - What we know: The C `whisper_full_params` has a `language` field (const char *)
   - What's unclear: Whether SwiftWhisper exposes this as `String`, an enum, or not at all
   - Recommendation: At implementation time, inspect `SwiftWhisper/Sources/SwiftWhisper/Whisper.swift` after adding the package; fall back to setting no language (whisper auto-detects Chinese accurately for large-v3-turbo)

2. **SwiftWhisper + Swift concurrency (actor isolation)**
   - What we know: The `transcribe` method is `async throws`
   - What's unclear: Whether the `Whisper` class is safe to call from a Swift `actor` or needs `@unchecked Sendable` annotation
   - Recommendation: Wrap in an `actor` with a single `Whisper` instance; if Swift complains about Sendable, use `nonisolated(unsafe)` or a serial background queue wrapper

3. **Package.swift sources list — Xcode vs SPM builds**
   - What we know: Current `Package.swift` lists explicit source files; adding SwiftWhisper requires updating `dependencies` and the target's `dependencies` array
   - What's unclear: Whether the current `Package.swift` is used for actual builds (Xcode project exists) or only for `swift build` verification
   - Recommendation: Update both `Package.swift` AND `Typeness.xcodeproj` in Phase 2; the existing Phase 1 plan set the precedent of maintaining both

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | None detected — Wave 0 must add XCTest or Swift Testing |
| Config file | None — see Wave 0 |
| Quick run command | `swift test --filter TypenessTests` (after Wave 0 setup) |
| Full suite command | `swift test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUDIO-01 | AVAudioConverter produces 16kHz mono Float32 from synthetic 44.1kHz buffer | unit | `swift test --filter AudioCaptureEngineTests/testResamplingFormat` | Wave 0 |
| AUDIO-02 | Permission status is checked before engine start | unit (mock AVCaptureDevice) | `swift test --filter AudioCaptureEngineTests/testPermissionCheck` | Wave 0 |
| AUDIO-03 | Start/stop latency within 100ms of notification | manual-only | N/A — requires real microphone hardware timing | manual-only |
| STT-01 | Transcription returns non-empty string for real speech frames | integration (real model) | Manual test run with debug log | manual-only |
| STT-02 | ModelManager download completes and file exists at expected path | integration | `swift test --filter ModelManagerTests/testWhisperModelDownload` | Wave 0 |
| STT-03 | hasVADThreshold returns false for zero-filled buffer | unit | `swift test --filter VADTests/testSilenceRejected` | Wave 0 |

**Note on AUDIO-03 and STT-01:** These require real hardware (microphone + GPU). They are manually verified. For STT-01, use the debug mode planned in Phase 4 or add a simple `print` in the transcription path.

### Sampling Rate

- **Per task commit:** `swift test --filter TypenessTests` (unit tests only, ~5s)
- **Per wave merge:** `swift test` (full suite)
- **Phase gate:** Full suite green + manual smoke test of recording + transcription before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] `Tests/TypenessTests/AudioCaptureEngineTests.swift` — covers AUDIO-01, AUDIO-02
- [ ] `Tests/TypenessTests/VADTests.swift` — covers STT-03
- [ ] `Tests/TypenessTests/ModelManagerTests.swift` — covers STT-02 (may need to mock URLSession)
- [ ] `Tests/TypenessTests/XCTestManifests.swift` — test entry point
- [ ] `Package.swift` test target: add `.testTarget(name: "TypenessTests", dependencies: ["Typeness"], path: "Tests/TypenessTests")`
- [ ] Framework install: already available (XCTest via Swift toolchain) — no extra install needed

---

## Sources

### Primary (HIGH confidence)
- SwiftWhisper GitHub (github.com/exPHAT/SwiftWhisper) — SPM URL, product name, transcribe API, CoreML support
- Apple Developer Documentation (AVAudioConverter) — resampling approach, inputBlock pattern
- Apple TN3136 (developer.apple.com/documentation/technotes/tn3136-avaudioconverter-performing-sample-rate-conversions) — official resampling guidance
- Apple Developer Documentation (AVCaptureDevice authorizationStatus) — macOS permission API
- Apple Accelerate (vDSP_rmsqv) — VAD RMS computation

### Secondary (MEDIUM confidence)
- whisper.spm Package.swift fetch (ggerganov/whisper.spm) — confirmed product name "whisper" and archived status
- whisper.cpp GitHub README fetch — Metal GPU auto-detection confirmed
- Multiple community sources (Medium, Swift Forums) — AVAudioEngine tap-at-native-rate behavior, converter gotchas

### Tertiary (LOW confidence)
- whisper.cpp main repo Package.swift — COULD NOT VERIFY (429 rate limit); product name for direct main-repo SPM integration is unverified. This is the STATE.md blocker. Mitigation: use SwiftWhisper.
- SwiftWhisper params.language Swift API shape — not confirmed; inferred from whisper.cpp C API structure

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — SwiftWhisper SPM URL and product name verified from official README; AVFoundation APIs verified from Apple docs
- Architecture: HIGH — AVAudioEngine + AVAudioConverter pattern is Apple-documented and community-verified; whisper.cpp C API well-documented
- Pitfalls: MEDIUM-HIGH — converter inputBlock multiple-calls pitfall is well-known; whisper hallucination on silence is widely documented; SPM product name for main repo is LOW confidence (mitigated by using SwiftWhisper)
- Validation: MEDIUM — test patterns are standard Swift/XCTest; no existing test infrastructure detected

**Research date:** 2026-03-16
**Valid until:** 2026-06-16 (90 days — AVFoundation APIs are stable; SwiftWhisper tracks whisper.cpp master so verify at implementation)
