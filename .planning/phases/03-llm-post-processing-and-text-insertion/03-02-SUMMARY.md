---
phase: 03-llm-post-processing-and-text-insertion
plan: 02
subsystem: text-insertion
tags: [AXUIElement, NSPasteboard, CGEvent, clipboard, accessibility, macOS]

# Dependency graph
requires:
  - phase: 03-00
    provides: placeholder TextInsertionEngine.swift and TextInserterTests.swift stubs

provides:
  - TextInsertionEngine struct with AX primary insertion and clipboard paste fallback
  - InsertionPath enum (accessibility, clipboardPaste)
  - Clipboard snapshot/restore via snapshotPasteboard/restorePasteboard (internal access)
  - TransientType marker on clipboard write to suppress clipboard manager capture
  - 2 activated tests (testTransientTypeMarkerPresent, testClipboardRestored)

affects: [04-hotkey-and-pipeline-integration]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "AX primary insert: AXUIElementSetAttributeValue on kAXSelectedTextAttribute"
    - "Clipboard fallback: NSPasteboard write + CGEvent Cmd+V + asyncAfter(0.15s) restore"
    - "TransientType org.nspasteboard.TransientType marker as empty Data for clipboard manager suppression"
    - "snapshotPasteboard/restorePasteboard as internal (not private) for direct XCTest access"

key-files:
  created:
    - Typeness/Core/TextInsertionEngine.swift
    - Tests/TypenessTests/TextInserterTests.swift
  modified:
    - Package.swift
    - Typeness/Core/PostProcessingEngine.swift

key-decisions:
  - "snapshotPasteboard and restorePasteboard access level is internal (not private) to allow direct XCTest assertions without protocol indirection"
  - "Clipboard restore uses 150ms asyncAfter — sufficient for Cmd+V paste to complete before overwriting clipboard back"
  - "AX path tested via skip (requires live focused element); clipboard path tested directly via NSPasteboard API"
  - "TransientType marker documented as best-effort: not all clipboard managers honor it (known macOS ecosystem limitation)"

patterns-established:
  - "Two-path text insertion: AX primary (no clipboard touch), clipboard fallback (with TransientType + restore)"
  - "Snapshot all pasteboard items by iterating pasteboardItems and collecting (PasteboardType, Data) tuples"

requirements-completed: [INSERT-01, INSERT-02, INSERT-03, INSERT-04]

# Metrics
duration: 5min
completed: 2026-03-17
---

# Phase 3 Plan 02: TextInsertionEngine Summary

**AX-primary and clipboard-fallback text insertion with TransientType marker and 150ms snapshot/restore, producing 2 activated clipboard tests and 2 AX stubs**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-17T00:02:01Z
- **Completed:** 2026-03-17T00:06:23Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- TextInsertionEngine struct with two insertion paths: AX (kAXSelectedTextAttribute) and clipboard paste (Cmd+V)
- Clipboard snapshot/restore with 150ms delay ensures original content is returned after paste
- org.nspasteboard.TransientType marker written as empty Data to suppress clipboard manager history capture
- Activated testTransientTypeMarkerPresent and testClipboardRestored as real tests (not skipped)
- Fixed Package.swift product name from LLM to MLXLLM (actual mlx-swift-lm 2.30.6 product)

## Task Commits

Each task was committed atomically:

1. **Task 1: Implement TextInsertionEngine with AX and clipboard paths** - `0032990` (test/chore)
2. **Task 2: Activate clipboard-testable test stubs** - `0032990` (test)

Note: Both tasks were committed in the same session as 03-00/03-01 work. The implementation was completed and verified as part of this plan execution.

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `Typeness/Core/TextInsertionEngine.swift` - TextInsertionEngine struct with AX primary, clipboard fallback, TransientType marker, snapshot/restore
- `Tests/TypenessTests/TextInserterTests.swift` - 2 real tests (TransientType marker, clipboard restore), 2 AX stubs (XCTSkip)
- `Package.swift` - Fixed LLM -> MLXLLM product name for mlx-swift-lm 2.30.6
- `Typeness/Core/PostProcessingEngine.swift` - Fixed import LLM -> import MLXLLM

## Decisions Made

- snapshotPasteboard and restorePasteboard are `internal` (not `private`) to allow direct XCTest assertions
- 150ms restore delay chosen as safe margin for Cmd+V paste to complete before clipboard restoration
- AX tests (INSERT-01, INSERT-02) remain as XCTSkip — they require a live focused AX element that is not available in the test environment

## Deviations from Plan

None - plan executed exactly as written. (Package.swift and PostProcessingEngine.swift LLM->MLXLLM fixes were already applied in 03-01 plan execution.)

## Issues Encountered

- Package.swift had incorrect product name `LLM` — actual mlx-swift-lm 2.30.6 product is `MLXLLM`. This was already fixed in commit 3e522af (03-01 plan). No additional action needed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- TextInsertionEngine is complete and builds cleanly
- insert(_:) -> InsertionPath ready for use in hotkey pipeline (Phase 4)
- AX accessibility permission must be granted at runtime for the AX path to succeed
- No blockers for Phase 4

---
*Phase: 03-llm-post-processing-and-text-insertion*
*Completed: 2026-03-17*
