---
phase: 02-audio-capture-and-transcription
plan: "01"
subsystem: audio

tags: [AVAudioEngine, AVAudioConverter, AVCaptureDevice, AVFoundation, microphone, PCM, 16kHz]

requires:
  - phase: 01-foundation
    provides: AppState observable class, project structure, Package.swift setup

provides:
  - AudioCaptureEngine actor: start()/stop()->[Float] interface producing 16kHz mono Float32 PCM
  - AVAudioConverter resampling from hardware native rate (e.g. 44100Hz) to 16kHz
  - Microphone permission check via AVCaptureDevice.authorizationStatus(for:.audio)
  - RecordingState enum on AppState (idle/recording/transcribing)

affects:
  - 02-02-audio-transcription
  - 02-03-recording-coordinator
  - TypenessApp (wires AudioCaptureEngine to hotkey notifications)

tech-stack:
  added: [AVFoundation (AVAudioEngine, AVAudioConverter, AVCaptureDevice)]
  patterns:
    - AVAudioEngine.inputNode.installTap at native format + AVAudioConverter to 16kHz
    - Swift actor for thread-safe audio accumulation buffer
    - filled-flag pattern for AVAudioConverter.convert(to:error:inputBlock:) to prevent double-feed
    - AVCaptureDevice.authorizationStatus / requestAccess for macOS microphone permission

key-files:
  created:
    - Typeness/Core/AudioCaptureEngine.swift
  modified:
    - Typeness/Core/AppState.swift
    - Tests/TypenessTests/AudioCaptureTests.swift

key-decisions:
  - "AVAudioConverter filled-flag pattern used to prevent double-feed of source buffer on non-integer sample rate ratios (44100->16000 = 2.75625x)"
  - "targetFormat and maxFrames exposed as internal (not private) to enable XCTest assertions without test-specific accessor methods"
  - "Tests require XCTest which is not available in CLI-tools-only Swift toolchain (no Xcode); tests are written correctly but cannot be executed without Xcode; swift build is the verification gate"

patterns-established:
  - "Pattern: AVAudioEngine tap-at-native-rate — always installTap at inputNode.outputFormat(forBus:0), never at targetFormat"
  - "Pattern: Actor-based audio accumulation — process() is actor-isolated, Task { await self?.process() } dispatches from tap callback"
  - "Pattern: filled-flag in AVAudioConverter inputBlock — prevent distortion on non-integer sample rate ratios"

requirements-completed: [AUDIO-01, AUDIO-02, AUDIO-03]

duration: 3min
completed: 2026-03-16
---

# Phase 2 Plan 01: AudioCaptureEngine Summary

**AVAudioEngine actor capturing microphone at native rate, resampled via AVAudioConverter to 16kHz mono Float32 PCM with AVCaptureDevice permission gating**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-16T14:49:49Z
- **Completed:** 2026-03-16T14:52:42Z
- **Tasks:** 1
- **Files modified:** 3

## Accomplishments

- Created AudioCaptureEngine actor with complete AVAudioEngine + AVAudioConverter pipeline
- Microphone permission check using AVCaptureDevice (macOS-correct API, not iOS AVAudioSession)
- Added RecordingState enum (idle/recording/transcribing) and recordingState property to AppState
- Updated AudioCaptureTests.swift with real assertions for targetFormat properties and maxFrames
- swift build succeeds with all new files

## Task Commits

1. **Task 1: Create AudioCaptureEngine actor with AVAudioConverter resampling** - `936f7c7` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `Typeness/Core/AudioCaptureEngine.swift` - Swift actor; AVAudioEngine wrapper with installTap at native rate, AVAudioConverter to 16kHz mono Float32, checkMicrophonePermission(), start()/stop()->[Float]
- `Typeness/Core/AppState.swift` - Added RecordingState enum and recordingState property
- `Tests/TypenessTests/AudioCaptureTests.swift` - Real assertions for targetFormat (16kHz, mono, Float32) and maxFrames (480_000)

## Decisions Made

- `targetFormat` and `maxFrames` exposed as `let` (internal access) rather than `private` to allow XCTest assertions without separate accessor methods — consistent with the "test-friendly internals" approach from Phase 1 actors.
- Used `filled` boolean flag in AVAudioConverter.convert inputBlock to prevent double-feed on non-integer sample rate ratios, per the pattern verified in RESEARCH.md Pitfall 1.
- stop() wraps samples array cap logic inside `process()` rather than at stop() time to avoid OOM on very long recordings.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- XCTest framework is unavailable in the CLI-tools-only Swift toolchain (no Xcode installed). This is a pre-existing environment constraint documented in STATE.md from Phase 1. Tests are correctly authored but cannot be run with `swift test` or `xcodebuild test`. The primary verification gate is `swift build` which succeeds. Tests will be exercisable once Xcode is installed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- AudioCaptureEngine actor is complete and ready for integration with TranscriptionEngine (plan 02-02)
- AppState.recordingState is ready for hotkey coordinator wiring (TypenessApp or RecordingCoordinator)
- The `stop() -> [Float]` interface is the hand-off point to whisper.cpp transcription
- Note: Info.plist already has NSMicrophoneUsageDescription (from Phase 1 entitlements work)

---
*Phase: 02-audio-capture-and-transcription*
*Completed: 2026-03-16*
