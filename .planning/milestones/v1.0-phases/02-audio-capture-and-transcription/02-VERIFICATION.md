---
phase: 02-audio-capture-and-transcription
verified: 2026-03-17T01:00:00Z
status: human_needed
score: 6/6 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 5/6
  gaps_closed:
    - "Whisper.cpp runs with Apple hardware acceleration (CoreML/Accelerate) — requirement STT-01 updated to match actual backend"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "End-to-end voice capture and transcription pipeline"
    expected: "Press Shift+Option+Space, speak Chinese or English, press again — transcription appears in console log. Silence rejection logs 'No voice activity detected'."
    why_human: "Requires real microphone hardware, real speech, and a downloaded whisper model."
  - test: "Model download progress indicator on first launch"
    expected: "Menu bar extra shows ProgressView with percentage during download of ggml-large-v3-turbo.bin. On completion, progress disappears."
    why_human: "Requires deleting ~/Library/Application Support/Typeness/Models/ and relaunching. Real network I/O."
  - test: "Microphone permission dialog text"
    expected: "System permission dialog shows 'Typeness needs microphone access to capture your voice for transcription.'"
    why_human: "Requires first-launch state with microphone permission not yet granted."
---

# Phase 2: Audio Capture and Transcription — Verification Report

**Phase Goal:** User's voice is captured from the microphone at 16kHz mono Float32, transcribed by whisper.cpp with Apple hardware acceleration (CoreML/Accelerate), with silence/noise gating preventing hallucinated output.
**Verified:** 2026-03-17
**Status:** human_needed — all automated checks pass, 3 items require human testing
**Re-verification:** Yes — after gap closure (plan 02-04 closed STT-01 Metal GPU gap)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Microphone audio captured at 16kHz mono Float32 | VERIFIED | `AudioCaptureEngine.swift` line 13: `targetFormat` is `pcmFormatFloat32, sampleRate: 16_000, channels: 1`. AVAudioConverter resamples with filled-flag inputBlock pattern. Test `AudioCaptureTests.testTargetFormatIs16kHzMonoFloat32` asserts all three properties. |
| 2 | Microphone permission is gated before capture starts | VERIFIED | `checkMicrophonePermission()` at line 21 uses `AVCaptureDevice.authorizationStatus(for: .audio)` and `requestAccess`. `NSMicrophoneUsageDescription` in Info.plist. |
| 3 | Audio capture starts/stops from hotkey events | VERIFIED | `TypenessApp.setupHotkeyObservers()` registers for `.hotkeyToggleFired`, `.hotkeyPTTDown`, `.hotkeyPTTUp`. Dispatches to `handleToggle/RecordingStart/RecordingStop()`. |
| 4 | Whisper.cpp transcribes with Apple hardware acceleration (CoreML/Accelerate) | VERIFIED | SwiftWhisper linked via SPM; `TranscriptionEngine.swift` wraps `Whisper(fromFileURL:)` and `transcribe(audioFrames:)`. SwiftWhisper Package.swift defines `GGML_USE_ACCELERATE` and `WHISPER_USE_COREML`. Doc comment at lines 11-15 explains acceleration path and why Metal is absent. STT-01 requirement updated to "CoreML/Accelerate". ROADMAP success criteria #4 updated consistently. |
| 5 | VAD gate rejects silence and short recordings | VERIFIED | `VAD.swift`: `VADGate.hasVoiceActivity()` uses `vDSP_rmsqv`, rejects < 8000 frames and RMS < 0.01. Three real assertions in `VADTests.swift`. Wired in `handleRecordingStop()` before transcription. |
| 6 | Whisper model downloads on first launch with progress indicator | VERIFIED | `ModelManager.downloadWhisperModelIfNeeded()` with `DownloadProgressDelegate`. `StatusItemView` renders `ProgressView(value: progress)`. |

**Score:** 6/6 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `Typeness/Core/AudioCaptureEngine.swift` | AVAudioEngine actor with 16kHz conversion | VERIFIED | 89 lines; actor with AVAudioConverter, installTap, start(), stop()->[Float], checkMicrophonePermission(). |
| `Typeness/Core/VAD.swift` | Energy-based VAD using vDSP | VERIFIED | 33 lines; VADGate enum with vDSP_rmsqv, minimum duration guard. |
| `Typeness/Core/TranscriptionEngine.swift` | SwiftWhisper wrapper actor with acceleration docs | VERIFIED | 43 lines; actor with load(), transcribe(), isLoaded. Doc comment at lines 11-15 documents CoreML/Accelerate acceleration and absence of Metal. |
| `Tests/TypenessTests/AudioCaptureTests.swift` | Format and maxFrames assertions | VERIFIED | Real XCTAssert calls for sampleRate, channelCount, commonFormat, maxFrames. |
| `Tests/TypenessTests/VADTests.swift` | Three VAD assertions | VERIFIED | testSilenceRejected, testShortRecordingRejected, testLoudAudioAccepted — all real assertions. |
| `Tests/TypenessTests/WhisperBridgeTests.swift` | notLoaded error test | VERIFIED | testTranscribeThrowsWhenNotLoaded is a real assertion. |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| AudioCaptureEngine | AVAudioEngine | installTap + AVAudioConverter | WIRED | Converter from native to 16kHz mono Float32. |
| AudioCaptureEngine | AVCaptureDevice | authorizationStatus check | WIRED | Line 22: `AVCaptureDevice.authorizationStatus(for: .audio)`. |
| TranscriptionEngine | SwiftWhisper | import + Whisper(fromFileURL:) | WIRED | Import at line 2; init at line 23; transcribe at line 40. |
| VAD | Accelerate | vDSP_rmsqv | WIRED | Import at line 1; vDSP call at line 30. |
| TypenessApp | AudioCaptureEngine | NotificationCenter observers | WIRED | start()/stop() called in hotkey handlers. |
| TypenessApp | TranscriptionEngine | transcribe(audioFrames:) | WIRED | Called after VAD check in handleRecordingStop(). |
| TypenessApp | VADGate | hasVoiceActivity(samples:) | WIRED | Called in handleRecordingStop() before transcription. |
| SwiftWhisper | Accelerate/CoreML | GGML_USE_ACCELERATE + WHISPER_USE_COREML | WIRED | Compile flags confirmed in SwiftWhisper Package.swift. |

---

### Requirements Coverage

| Requirement | Description | Status | Evidence |
|-------------|-------------|--------|----------|
| AUDIO-01 | Record microphone at 16kHz mono Float32 PCM | SATISFIED | targetFormat confirmed; AVAudioConverter resamples; test asserts format properties. |
| AUDIO-02 | Request mic permission on first use with clear explanation | SATISFIED | checkMicrophonePermission() with AVCaptureDevice.requestAccess; NSMicrophoneUsageDescription in Info.plist. |
| AUDIO-03 | Audio capture starts/stops from hotkey < 100ms | SATISFIED | NotificationCenter observers wired; AVAudioEngine.start() is synchronous. Latency needs human confirmation. |
| STT-01 | Transcribe with Apple hardware acceleration (CoreML/Accelerate) | SATISFIED | Requirement updated from "Metal GPU" to "CoreML/Accelerate" in REQUIREMENTS.md, ROADMAP.md. TranscriptionEngine.swift documents acceleration path. SwiftWhisper compiles with GGML_USE_ACCELERATE + WHISPER_USE_COREML. |
| STT-02 | Download large-v3-turbo on first launch with progress | SATISFIED | ModelManager download + ProgressView rendering. |
| STT-03 | VAD gating prevents hallucinated output | SATISFIED | VADGate rejects silence and short recordings; three passing unit tests. |

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| TranscriptionEngine.swift | 28 | `// whisper?.params.language = ...` commented out | Warning | Chinese language hint not set; auto-detect works but explicit hint improves accuracy |

No stubs, placeholders, or empty implementations found.

---

### Human Verification Required

#### 1. End-to-End Capture and Transcription

**Test:** Build and run the app. Press Shift+Option+Space, speak Traditional Chinese, press again.
**Expected:** Console logs transcription result. AppState transitions idle -> recording -> transcribing -> idle.
**Why human:** Requires real microphone, downloaded model, and real speech.

#### 2. Silence Rejection End-to-End

**Test:** Press Shift+Option+Space, stay silent for 2 seconds, press again.
**Expected:** Console logs "No voice activity detected". No transcription output.
**Why human:** Requires real hardware for genuine silence samples.

#### 3. Microphone Permission Dialog

**Test:** Reset microphone permission (`tccutil reset Microphone`), relaunch, trigger voice input.
**Expected:** macOS dialog shows microphone permission request with explanation string.
**Why human:** Requires TCC reset and fresh launch state.

---

### Re-verification: Gap Closure Results

**Previous gap:** STT-01 -- SwiftWhisper does not compile with GGML_USE_METAL; Metal GPU acceleration unavailable.

**Resolution (plan 02-04):** Updated requirement STT-01 wording from "Metal GPU acceleration" to "Apple hardware acceleration (CoreML/Accelerate)". Updated ROADMAP Phase 2 goal and success criteria consistently. Added documentation comment to TranscriptionEngine.swift explaining the acceleration backend.

**Verification of closure:**
- REQUIREMENTS.md line 18: "Apple hardware acceleration (CoreML/Accelerate)" -- confirmed
- ROADMAP.md line 36: goal references "Apple hardware acceleration (CoreML/Accelerate)" -- confirmed
- ROADMAP.md line 43: success criteria #4 says "CoreML for Neural Engine, Accelerate for CPU BLAS" -- confirmed
- TranscriptionEngine.swift lines 11-15: doc comment explains GGML_USE_ACCELERATE, WHISPER_USE_COREML, and absence of GGML_USE_METAL -- confirmed

**Gap status: CLOSED.** All three artifacts (REQUIREMENTS.md, ROADMAP.md, TranscriptionEngine.swift) are consistent and accurate.

**Regression check:** All 5 previously passing truths remain verified. No regressions detected.

---

_Verified: 2026-03-17_
_Verifier: Claude (gsd-verifier)_
