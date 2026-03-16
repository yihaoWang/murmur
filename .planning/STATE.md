# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-16)

**Core value:** Fast, reliable voice-to-text input that feels native to macOS — press hotkey, speak, text appears at cursor with correct punctuation and formatting.
**Current focus:** Phase 1 — Foundation

## Current Position

Phase: 1 of 4 (Foundation)
Plan: 0 of TBD in current phase
Status: Ready to plan
Last activity: 2026-03-16 — Roadmap created

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**
- Last 5 plans: —
- Trend: —

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Project init: whisper.cpp over Apple Speech (Chinese quality + consistency with Python version)
- Project init: MLX Swift for LLM (native Apple Silicon, same model ecosystem)
- Project init: SwiftUI over AppKit (modern macOS, less boilerplate)
- Project init: Menu bar app LSUIElement style (matches Python version)

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2: whisper.cpp SPM product name needs verification against actual Package.swift before implementation
- Phase 3: mlx-swift-lm 2.30.6 API surface (LLMModelFactory / ChatSession) needs verification against current source
- Phase 3: NSPasteboard TransientType behavior across clipboard managers is best-effort; document as known limitation

## Session Continuity

Last session: 2026-03-16
Stopped at: Roadmap created, STATE.md initialized
Resume file: None
