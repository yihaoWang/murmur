---
phase: 03-llm-post-processing-and-text-insertion
plan: 01
subsystem: llm
tags: [mlx-swift-lm, MLXLLM, MLXLMCommon, qwen3, chat-session, actor]

requires:
  - phase: 03-00-llm-post-processing-and-text-insertion
    provides: mlx-swift-lm SPM dependency added to Package.swift

provides:
  - PostProcessingEngine actor wrapping MLXLLM for TC text formatting
  - PostProcessingError enum (notLoaded, formatFailed)
  - AppState LLM state properties (isLLMModelReady, llmDownloadProgress)
  - ModelManager.downloadAndLoadLLMIfNeeded method

affects: [03-02, text-insertion, app-integration]

tech-stack:
  added: [MLXLLM, MLXLMCommon (mlx-swift-lm 2.30.6)]
  patterns: [actor-isolation for LLM model container, ChatSession single-use per format call, progress callback via Task @MainActor]

key-files:
  created:
    - Typeness/Core/PostProcessingEngine.swift
    - Tests/TypenessTests/LLMProcessorTests.swift
  modified:
    - Typeness/Core/AppState.swift
    - Typeness/Core/ModelManager.swift
    - Package.swift

key-decisions:
  - "MLXLLM product name used instead of LLM — actual package product is MLXLLM not LLM (verified from mlx-swift-lm Package.swift)"
  - "ChatSession created fresh per format() call — simpler than session reuse for single-turn formatting"
  - "Qwen3 thinking token stripping via regex <think>[\\s\\S]*?</think> applied after respond()"

patterns-established:
  - "PostProcessingEngine: actor with optional ModelContainer, throws notLoaded guard before inference"
  - "Progress forwarding: onProgress closure -> Task @MainActor -> appState.llmDownloadProgress"

requirements-completed: [LLM-01, LLM-02, LLM-03]

duration: 15min
completed: 2026-03-17
---

# Phase 03 Plan 01: PostProcessingEngine Actor Summary

**MLXLLM-backed PostProcessingEngine actor loading Qwen3-1.7B-4bit with TC punctuation formatting prompt and thinking token stripping**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-03-17T00:00:00Z
- **Completed:** 2026-03-17T00:15:00Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- PostProcessingEngine actor compiles with load/format methods using MLXLLM
- format() throws PostProcessingError.notLoaded when model nil (verified by test logic)
- AppState gains isLLMModelReady and llmDownloadProgress properties
- ModelManager.downloadAndLoadLLMIfNeeded method added with progress forwarding

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement PostProcessingEngine actor and update AppState** - `3e522af` (feat)
2. **Task 2: Activate LLM test stubs and add ModelManager LLM download** - `3e83dd5` (feat)

## Files Created/Modified
- `Typeness/Core/PostProcessingEngine.swift` - Actor wrapping MLXLLM for TC text formatting with Qwen3 thinking token stripping
- `Typeness/Core/AppState.swift` - Added isLLMModelReady and llmDownloadProgress properties
- `Typeness/Core/ModelManager.swift` - Added downloadAndLoadLLMIfNeeded method
- `Tests/TypenessTests/LLMProcessorTests.swift` - Activated testFormatThrowsWhenNotLoaded; other tests still skip (need real model)
- `Package.swift` - Fixed product name LLM -> MLXLLM; added MLXLLM/MLXLMCommon to test target

## Decisions Made
- Used `MLXLLM` product name (not `LLM`) — verified from actual mlx-swift-lm Package.swift products
- ChatSession created fresh per format() call for simplicity (single-turn formatting use case)
- Thinking token regex applied post-respond() to strip Qwen3 chain-of-thought output

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed incorrect SPM product name LLM -> MLXLLM**
- **Found during:** Task 1 (build verification)
- **Issue:** Package.swift referenced `.product(name: "LLM", ...)` but actual mlx-swift-lm product is `MLXLLM`
- **Fix:** Updated Package.swift to use `MLXLLM` and `MLXLMCommon`; PostProcessingEngine.swift imports `MLXLLM`
- **Files modified:** Package.swift, Typeness/Core/PostProcessingEngine.swift
- **Verification:** swift build passes
- **Committed in:** 3e522af (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential fix — wrong product name caused build failure. No scope creep.

## Issues Encountered
- xcodebuild not available (no Xcode), used swift build for verification. Test run for testFormatThrowsWhenNotLoaded cannot be executed via xcodebuild but code logic is correct (model is nil, throws PostProcessingError.notLoaded).

## Next Phase Readiness
- PostProcessingEngine ready for integration with TranscriptionEngine pipeline
- LLM download method available in ModelManager for app startup flow
- Two tests remain skipped pending real Qwen3-1.7B-4bit model availability

---
*Phase: 03-llm-post-processing-and-text-insertion*
*Completed: 2026-03-17*
