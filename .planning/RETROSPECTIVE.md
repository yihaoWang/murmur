# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-17
**Phases:** 5 | **Plans:** 15

### What Was Built
- Complete voice-to-text pipeline: hotkey → audio capture → whisper.cpp transcription → Qwen3-1.7B formatting → cursor insertion
- Menu bar app with SwiftUI settings, permissions onboarding, and dynamic status icons
- Debug mode with WAV + JSON archiving; confirm-before-insert review panel
- Dual-path text insertion (Accessibility API + clipboard paste fallback)

### What Worked
- Parallel plan execution within phases significantly reduced total time
- Phase research agents caught critical issues early (SwiftWhisper product name, MLXLLM vs LLM)
- Milestone audit + gap closure cycle caught real integration bugs that per-phase verification missed
- Actor pattern for engines (TranscriptionEngine, PostProcessingEngine) provided clean async boundaries

### What Was Inefficient
- MLXLLM product name was wrong in research docs — caused build failures that had to be fixed during execution
- Phase 3/4 plan checkboxes in ROADMAP.md were not updated to [x] during execution (cosmetic but confusing)
- Some phase SUMMARY.md files lacked one_liner frontmatter, making automated accomplishment extraction fail

### Patterns Established
- `loadSettings(from:)` pattern for applying persisted config to runtime objects at startup
- `PendingDebugContext` pattern for passing data across async boundaries to UI callbacks
- `KeyboardShortcuts.disable()` to prevent framework conflicts with custom CGEventTap
- VADGate energy threshold as pre-filter before expensive Whisper inference

### Key Lessons
1. Integration testing at milestone level catches wiring bugs that per-phase unit verification misses — always run milestone audit
2. SPM product names must be verified against actual Package.swift before use in plans — research docs can be wrong
3. SwiftUI .sheet on MenuBarExtra dismisses on focus loss — any state machine using sheets must handle this dismiss path

### Cost Observations
- Model mix: primarily opus for orchestration, sonnet for research/checking/integration, haiku for quick tasks
- Sessions: ~4 sessions across 1 day
- Notable: 5 phases in 1 day is very fast for a complete macOS app with STT + LLM pipeline

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Phases | Plans | Key Change |
|-----------|--------|-------|------------|
| v1.0 | 5 | 15 | Initial milestone — established parallel execution, audit cycle |

### Top Lessons (Verified Across Milestones)

1. Always verify SPM product names against actual Package.swift before planning
2. Milestone audit → gap closure is essential for integration quality
