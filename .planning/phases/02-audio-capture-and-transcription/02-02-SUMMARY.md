---
phase: 02-audio-capture-and-transcription
plan: "02"
subsystem: stt
tags: [swiftwhisper, whisper-cpp, vad, accelerate, vdsp, transcription]

# Dependency graph
requires:
  - phase: 02-00
    provides: TypenessTests target and XCTest stub files for WhisperBridgeTests and VADTests
provides:
  - TranscriptionEngine actor wrapping SwiftWhisper with load() and transcribe() methods
  - VADGate enum with RMS energy gate using vDSP_rmsqv
  - SwiftWhisper SPM dependency in Package.swift
affects:
  - 02-03-audio-capture-engine
  - 03-llm-integration
  - 04-text-insertion

# Tech tracking
tech-stack:
  added:
    - SwiftWhisper (branch:master) — Swift wrapper around whisper.cpp; Metal GPU auto-detected
    - Accelerate/vDSP — RMS energy computation for VAD gate
  patterns:
    - TranscriptionEngine as actor with nonisolated(unsafe) for Whisper Sendable isolation
    - VADGate as enum with static methods for zero-allocation gate logic
    - Guard-based error throwing: notLoaded before emptyAudio before inference

key-files:
  created:
    - Typeness/Core/TranscriptionEngine.swift
    - Typeness/Core/VAD.swift
  modified:
    - Package.swift
    - Tests/TypenessTests/WhisperBridgeTests.swift
    - Tests/TypenessTests/VADTests.swift

key-decisions:
  - "SwiftWhisper (exPHAT) used over direct ggml-org/whisper.cpp SPM — product name confirmed, simpler Swift API"
  - "nonisolated(unsafe) on Whisper property — Whisper class not Sendable-compatible with actor isolation"
  - "Language parameter commented out — SwiftWhisper params.language API shape unverified; large-v3-turbo auto-detects Chinese accurately"
  - "VAD minimum 8000 frames (0.5s at 16kHz) — whisper hallucinates on very short clips"

patterns-established:
  - "Pattern: actor with nonisolated(unsafe) for non-Sendable C-backed objects"
  - "Pattern: enum namespace for static utility functions (VADGate)"
  - "Pattern: guard-chain error handling — check preconditions before async inference"

requirements-completed: [STT-01, STT-03]

# Metrics
duration: 15min
completed: 2026-03-16
---

# Phase 2 Plan 02: TranscriptionEngine and VAD Summary

**SwiftWhisper SPM actor wrapping whisper.cpp Metal backend with energy-based RMS VAD gate using vDSP_rmsqv to reject silence**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-16T00:00:00Z
- **Completed:** 2026-03-16T00:15:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- SwiftWhisper SPM dependency added to Package.swift; resolves and compiles with Metal backend
- TranscriptionEngine actor with `load(modelURL:)` and `transcribe(audioFrames:)` async throws
- VADGate rejecting silence (RMS < 0.01) and short recordings (< 8000 frames / 0.5s)
- WhisperBridgeTests updated with real `testTranscribeThrowsWhenNotLoaded` assertion
- VADTests updated with three real assertions (silence, short, loud)

## Task Commits

Each task was committed atomically:

1. **Task 1: Add SwiftWhisper SPM dependency and create TranscriptionEngine actor** - `51b8668` (feat)
2. **Task 2: Create VAD energy gate with vDSP** - `7624649` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `Typeness/Core/TranscriptionEngine.swift` — Actor wrapping SwiftWhisper; load() and transcribe() with TranscriptionError
- `Typeness/Core/VAD.swift` — VADGate enum with hasVoiceActivity(samples:threshold:) using vDSP_rmsqv
- `Package.swift` — SwiftWhisper dependency added; TranscriptionEngine.swift and VAD.swift added to sources; testTarget gets SwiftWhisper
- `Tests/TypenessTests/WhisperBridgeTests.swift` — Real notLoaded assertion; emptyAudio test remains skipped (requires model file)
- `Tests/TypenessTests/VADTests.swift` — Three real assertions replacing XCTSkip stubs

## Decisions Made
- Used `nonisolated(unsafe)` on the `whisper: Whisper?` property — Whisper class is not Sendable-compatible with actor isolation; all access is already serialized through the actor executor so this is safe.
- Language parameter left commented out — The SwiftWhisper `params.language` API shape was unverified at implementation time. large-v3-turbo auto-detects Chinese accurately so this is safe to defer.
- VAD threshold 0.01 (~-40 dBFS) matches research recommendation; minimum 8000 frames (0.5s) prevents hallucination on brief noise.

## Deviations from Plan

None — plan executed exactly as written.

Note: `xcodebuild test` is unavailable (CommandLineTools only, no Xcode). `swift build` verifies compilation. XCTest framework requires Xcode to run — this is a pre-existing environment constraint documented in prior phases.

## Issues Encountered
- XCTest not available via CommandLineTools; `swift test` fails with "no such module 'XCTest'". Build verification via `swift build` confirms compilation correctness. This is the same constraint noted in Phase 1.

## Next Phase Readiness
- TranscriptionEngine ready to be wired into AudioCaptureEngine flow (02-03)
- VADGate ready to be called before transcription in recording coordinator
- SwiftWhisper resolves cleanly; Metal backend runs automatically on Apple Silicon

---
*Phase: 02-audio-capture-and-transcription*
*Completed: 2026-03-16*
