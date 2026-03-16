---
phase: 02-audio-capture-and-transcription
verified: 2026-03-17T00:00:00Z
status: gaps_found
score: 5/6 must-haves verified
gaps:
  - truth: "Whisper.cpp runs with Metal GPU acceleration"
    status: failed
    reason: "SwiftWhisper's Package.swift only defines GGML_USE_ACCELERATE and WHISPER_USE_COREML — GGML_USE_METAL is absent. The packaged whisper.cpp build uses the CPU Accelerate framework and CoreML only; the Metal GPU compute backend is not compiled in."
    artifacts:
      - path: ".build/checkouts/SwiftWhisper/Package.swift"
        issue: "cSettings defines GGML_USE_ACCELERATE and WHISPER_USE_COREML but NOT GGML_USE_METAL"
      - path: "Typeness/Core/TranscriptionEngine.swift"
        issue: "No Metal configuration passed at init; relies entirely on SwiftWhisper defaults which exclude Metal"
    missing:
      - "Either: fork/patch SwiftWhisper to add .define(\"GGML_USE_METAL\", .when(platforms: [.macOS])) in whisper_cpp target cSettings, OR switch to a whisper.cpp SPM dependency that compiles the Metal backend, OR document that CoreML (Neural Engine) is the accepted GPU acceleration path and update requirement STT-01 accordingly"
human_verification:
  - test: "End-to-end voice capture and transcription pipeline"
    expected: "Press Shift+Option+Space, speak Chinese or English, press again — transcription appears in console log. Silence rejection logs 'No voice activity detected'."
    why_human: "Requires real microphone hardware, real speech, and a downloaded whisper model. Cannot verify programmatically."
  - test: "Model download progress indicator on first launch"
    expected: "Menu bar extra shows ProgressView with percentage during download of ggml-large-v3-turbo.bin (~800MB). On completion, progress disappears and 'Whisper Model' status changes to ready."
    why_human: "Requires deleting ~/Library/Application Support/Typeness/Models/ and relaunching. Real network I/O."
  - test: "Microphone permission dialog text"
    expected: "System permission dialog shows 'Typeness needs microphone access to capture your voice for transcription.' when voice input is first triggered."
    why_human: "Requires first-launch state with microphone permission not yet granted."
---

# Phase 2: Audio Capture and Transcription — Verification Report

**Phase Goal:** User's voice is captured from the microphone at 16kHz mono Float32, transcribed by whisper.cpp with Metal GPU acceleration, with silence/noise gating preventing hallucinated output.
**Verified:** 2026-03-17
**Status:** gaps_found — 1 gap blocking the Metal GPU acceleration requirement
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Microphone audio captured at 16kHz mono Float32 | VERIFIED | `AudioCaptureEngine.swift`: `targetFormat` is `AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)`. `AVAudioConverter` resamples from native hardware rate using the verified `filled` boolean inputBlock pattern. |
| 2 | Microphone permission is gated before capture starts | VERIFIED | `checkMicrophonePermission()` uses `AVCaptureDevice.authorizationStatus(for: .audio)` and `requestAccess(for: .audio)`. `NSMicrophoneUsageDescription` confirmed in `Typeness/Info.plist` line 7. `handleRecordingStart()` guards on permission result before `audioEngine.start()`. |
| 3 | Audio capture starts/stops from hotkey events | VERIFIED | `TypenessApp.setupHotkeyObservers()` registers observers for `.hotkeyToggleFired`, `.hotkeyPTTDown`, `.hotkeyPTTUp`. Observers dispatch `Task { await handleToggle()/handleRecordingStart()/handleRecordingStop() }`. `AVAudioEngine.start()` + `installTap` is synchronous and well under 100ms. |
| 4 | Whisper.cpp transcribes audio with Metal GPU acceleration | FAILED | SwiftWhisper is linked and `transcribe(audioFrames:)` is correctly wired. However, the SwiftWhisper `Package.swift` at `.build/checkouts/SwiftWhisper/Package.swift` defines only `GGML_USE_ACCELERATE` and `WHISPER_USE_COREML` in `cSettings` — `GGML_USE_METAL` is absent. The Metal GPU compute backend is not compiled into the binary. Transcription will use CPU Accelerate + CoreML (Apple Neural Engine path), not Metal GPU. |
| 5 | VAD gate rejects silence and short recordings | VERIFIED | `VADGate.hasVoiceActivity()` in `VAD.swift` uses `vDSP_rmsqv` for RMS calculation, rejects samples below 8000 frames (0.5s) and below 0.01 RMS threshold. Wired in `handleRecordingStop()` before `transcriptionEngine.transcribe()`. Unit tests in `VADTests.swift` cover all three cases (silence, short, loud). |
| 6 | Whisper model downloads on first launch with progress indicator | VERIFIED | `ModelManager.downloadWhisperModelIfNeeded()` uses URLSession + `DownloadProgressDelegate` writing to `appState.modelDownloadProgress`. `StatusItemView.swift` renders a `ProgressView(value: progress)` when progress is non-nil. `TypenessApp` calls `downloadWhisperModelIfNeeded()` in the `.task` block. |

**Score:** 5/6 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Typeness/Core/AudioCaptureEngine.swift` | AVAudioEngine actor with 16kHz conversion | VERIFIED | 89 lines; actor with `AVAudioConverter`, `installTap`, `start()`, `stop()->[Float]`, `checkMicrophonePermission()`. |
| `Typeness/Core/VAD.swift` | Energy-based VAD using vDSP | VERIFIED | 33 lines; `VADGate` enum with `vDSP_rmsqv`, minimum duration guard. |
| `Typeness/Core/TranscriptionEngine.swift` | SwiftWhisper wrapper actor | VERIFIED (partial concern) | 36 lines; `TranscriptionEngine` actor with `load()`, `transcribe()`, `isLoaded`. SwiftWhisper linked correctly via SPM. Metal not compiled — see gap. |
| `Typeness/Core/AppState.swift` | RecordingState enum + properties | VERIFIED | Contains `enum RecordingState { case idle, recording, transcribing }`, `var recordingState`, `var lastTranscription`. |
| `Typeness/App/TypenessApp.swift` | Hotkey-to-pipeline wiring | VERIFIED | `setupHotkeyObservers()` registered, `handleToggle/Start/Stop()` fully implemented with VAD check and transcription call. |
| `Typeness/Info.plist` | NSMicrophoneUsageDescription | VERIFIED | Key found at line 7. |
| `Tests/TypenessTests/AudioCaptureTests.swift` | Format and maxFrames assertions | VERIFIED | Real assertions for `targetFormat` (sampleRate, channelCount, commonFormat) and `maxFrames == 480_000`. Permission test legitimately skipped (requires hardware). |
| `Tests/TypenessTests/VADTests.swift` | Three VAD assertions | VERIFIED | All three tests are real `XCTAssert` calls, not stubs. |
| `Tests/TypenessTests/WhisperBridgeTests.swift` | notLoaded error test | VERIFIED | `testTranscribeThrowsWhenNotLoaded` is a real assertion; `testTranscribeEmptyAudioThrows` skipped with valid reason (needs model file). |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `AudioCaptureEngine.swift` | `AVAudioEngine` | `installTap` + `AVAudioConverter` | WIRED | `AVAudioConverter(from: inputFormat, to: targetFormat)` confirmed. Tap installed at native rate, output is 16kHz mono Float32. |
| `AudioCaptureEngine.swift` | `AVCaptureDevice` | `authorizationStatus` check | WIRED | `AVCaptureDevice.authorizationStatus(for: .audio)` at line 22. |
| `TranscriptionEngine.swift` | `SwiftWhisper` | `import SwiftWhisper`, `Whisper(fromFileURL:)` | WIRED | Import confirmed; `whisper = Whisper(fromFileURL: modelURL)` at line 16; `whisper!.transcribe(audioFrames:)` at line 33. |
| `VAD.swift` | `Accelerate` | `vDSP_rmsqv` | WIRED | `import Accelerate` at line 1; `vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))` at line 30. |
| `TypenessApp.swift` | `AudioCaptureEngine` | NotificationCenter → `start()`/`stop()` | WIRED | `audioEngine.start()` at line 110; `audioEngine.stop()` at line 120. |
| `TypenessApp.swift` | `TranscriptionEngine` | `transcriptionEngine.transcribe(audioFrames:)` | WIRED | Called at line 130 after VAD check. |
| `TypenessApp.swift` | `VAD.swift` | `VADGate.hasVoiceActivity(samples:)` | WIRED | Called at line 123 in `handleRecordingStop()`. |
| `SwiftWhisper` | Metal GPU | `GGML_USE_METAL` compile flag | NOT WIRED | `.build/checkouts/SwiftWhisper/Package.swift` defines `GGML_USE_ACCELERATE` and `WHISPER_USE_COREML` only. No `GGML_USE_METAL`. Metal compute backend absent from binary. |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| AUDIO-01 | 02-01, 02-00 | Record microphone at 16kHz mono Float32 PCM | SATISFIED | `AudioCaptureEngine.targetFormat` is `pcmFormatFloat32`, 16_000 Hz, 1 channel. AVAudioConverter resamples from native rate. `AudioCaptureTests.testTargetFormatIs16kHzMonoFloat32` passes. |
| AUDIO-02 | 02-01, 02-00 | Request mic permission on first use with clear explanation | SATISFIED | `checkMicrophonePermission()` uses `AVCaptureDevice.requestAccess`. `NSMicrophoneUsageDescription` in Info.plist. Permission checked before `engine.start()` in every code path. |
| AUDIO-03 | 02-01, 02-00 | Audio capture starts/stops from hotkey < 100ms | SATISFIED (automated check only; latency requires human) | `handleRecordingStart/Stop()` are connected via `NotificationCenter` observers for all three hotkey notifications. `AVAudioEngine.start()` is synchronous and sub-millisecond. |
| STT-01 | 02-02, 02-00 | Transcribe audio using whisper.cpp **with Metal GPU acceleration** | BLOCKED | Whisper.cpp is linked via SwiftWhisper and transcription is wired correctly. However `GGML_USE_METAL` is not defined in SwiftWhisper's build — Metal backend is not compiled in. Acceleration is via Accelerate/CoreML only. |
| STT-02 | 02-03 | Download large-v3-turbo on first launch with progress indicator | SATISFIED | `ModelManager.downloadWhisperModelIfNeeded()` downloads from HuggingFace with `DownloadProgressDelegate`. `StatusItemView` renders `ProgressView(value: progress)`. |
| STT-03 | 02-02, 02-00 | VAD gating prevents hallucinated output on silence/noise | SATISFIED | `VADGate.hasVoiceActivity()` rejects silence (RMS < 0.01) and short recordings (< 8000 frames). Wired in `handleRecordingStop()`. All three `VADTests` are real assertions. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `Typeness/Core/TranscriptionEngine.swift` | 21 | `// whisper?.params.language = ...` commented out | Warning | Chinese language hint not set; large-v3-turbo auto-detects but explicit `zh` hint improves accuracy |
| `Typeness/Core/TypenessApp.swift` | 133 | `// Phase 3 will insert text at cursor; Phase 2 just logs` | Info | Expected — Phase 2 intentionally only logs transcription. Not a defect. |

No stub implementations, placeholder returns, or empty handlers found. All TODO items are legitimate deferred work for future phases.

---

### Human Verification Required

#### 1. End-to-End Capture and Transcription

**Test:** Build and run the app. Press Shift+Option+Space to start recording. Speak a phrase in Traditional Chinese (e.g., "你好世界"). Press Shift+Option+Space again to stop.
**Expected:** Console logs show `[Typeness] Transcription: 你好世界` (or close equivalent). AppState transitions idle → recording → transcribing → idle.
**Why human:** Requires real microphone hardware, downloaded whisper model (~800MB), and real speech input.

#### 2. Silence Rejection End-to-End

**Test:** Press Shift+Option+Space, stay completely silent for 2 seconds, press again.
**Expected:** Console logs `[Typeness] No voice activity detected, skipping transcription`. No transcription output.
**Why human:** Requires real hardware to produce genuine silence samples through the AVAudioEngine pipeline.

#### 3. Microphone Permission Dialog

**Test:** Reset microphone permission (`tccutil reset Microphone`), relaunch, trigger voice input.
**Expected:** macOS system dialog shows "Typeness needs microphone access to capture your voice for transcription."
**Why human:** Requires TCC permission reset and fresh launch state.

#### 4. Model Download Progress

**Test:** Delete `~/Library/Application Support/Typeness/Models/`, relaunch app.
**Expected:** Menu bar StatusItemView shows progress bar with percentage during download. After download completes, progress disappears.
**Why human:** Requires deleting model file and real network download.

---

### Gaps Summary

**One gap blocks requirement STT-01 (Metal GPU acceleration).**

The whisper.cpp build distributed by the SwiftWhisper SPM package is compiled with `GGML_USE_ACCELERATE` (Apple's Accelerate framework — CPU BLAS) and `WHISPER_USE_COREML` (Apple Neural Engine via CoreML). The `GGML_USE_METAL` flag — which enables whisper.cpp's Metal compute shaders for GPU inference — is not present in SwiftWhisper's `Package.swift`.

This means transcription on Apple Silicon will use the CPU Accelerate path (or CoreML if a CoreML model file is present alongside the GGML model). Metal GPU inference, which provides the fastest whisper.cpp performance on Apple Silicon, is not active.

**Recommended resolution options (in preference order):**

1. **Update the requirement** — If CoreML (Apple Neural Engine) inference is acceptable as "GPU acceleration," update STT-01 to say "Apple hardware acceleration" and close the gap. CoreML on Apple Silicon ANE is fast and energy-efficient, arguably better than Metal for this use case.

2. **Patch SwiftWhisper** — Add a local Package.swift override or fork SwiftWhisper to add `.define("GGML_USE_METAL", .when(platforms: [.macOS]))` to the `whisper_cpp` target cSettings and link the Metal framework. This requires also adding `ggml-metal.metal` to the bundle.

3. **Switch to a Metal-enabled whisper.cpp dependency** — Use a different SPM wrapper that compiles with Metal enabled, or use the main `ggml-org/whisper.cpp` repo which does enable Metal in recent versions.

**All other requirements (AUDIO-01, AUDIO-02, AUDIO-03, STT-02, STT-03) are fully satisfied** with substantive implementations, complete wiring, and automated test coverage where testable without hardware.

---

_Verified: 2026-03-17_
_Verifier: Claude (gsd-verifier)_
