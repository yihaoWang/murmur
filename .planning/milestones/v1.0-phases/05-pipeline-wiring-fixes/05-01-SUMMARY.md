---
phase: 05-pipeline-wiring-fixes
plan: 01
subsystem: pipeline-wiring
tags: [hotkey, llm, debug, ui, state-management]
dependency_graph:
  requires: []
  provides: [hotkey-modifier-sync, llm-progress-display, confirm-state-reset, debug-confirm-path]
  affects: [TypenessApp, AppState, StatusItemView]
tech_stack:
  added: []
  patterns: [PendingDebugContext-struct, KeyboardShortcuts-disable]
key_files:
  created: []
  modified:
    - Typeness/App/TypenessApp.swift
    - Typeness/Core/AppState.swift
    - Typeness/UI/StatusItemView.swift
decisions:
  - Kept KeyboardShortcuts.Name declarations but disabled interception via KeyboardShortcuts.disable() since Recorder API requires Name
metrics:
  duration: ~3min
  completed: 2026-03-17
---

# Phase 5 Plan 1: Pipeline Wiring Fixes Summary

Close 5 integration gaps: hotkey modifier sync via loadSettings(from:), LLM progress bar in StatusItemView, confirm-mode state reset on any sheet dismiss, debug archiving in confirm path via PendingDebugContext, and dual hotkey conflict resolution via KeyboardShortcuts.disable().

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Fix hotkey modifier sync and remove dual hotkey conflict | 1ba0cd5 | TypenessApp.swift |
| 2 | Fix LLM progress display, confirm-mode state reset, debug archiving | 1ba0cd5 | AppState.swift, StatusItemView.swift, TypenessApp.swift |
| 3 | Build verification and audit check | 1ba0cd5 | (verification only) |

## Changes Made

### TypenessApp.swift
- Replaced two manual `toggleKeyCode`/`pttKeyCode` assignments with single `hotkeyMonitor.loadSettings(from: settingsStore)` call that applies both keyCodes AND modifiers
- Added `KeyboardShortcuts.disable(.toggleMode)` and `.disable(.pushToTalk)` in `setupApp()` to prevent framework from intercepting keystrokes alongside CGEventTap
- Added `appState.llmDownloadProgress = nil` after LLM load completes
- Stored `PendingDebugContext` in confirm-before-insert branch when debug mode enabled

### AppState.swift
- Added `PendingDebugContext` struct with frames, rawTranscription, formattedText, latencyMs
- Added `pendingDebugContext: PendingDebugContext?` property

### StatusItemView.swift
- Added LLM download progress display (`else if` block after Whisper progress)
- Fixed sheet dismiss Binding to reset `recordingState = .idle` and clear `pendingDebugContext`
- Added `DebugArchiver.save()` call in `onConfirm` callback using stored debug context
- Clear `pendingDebugContext` in both `onConfirm` and `onCancel`

## Deviations from Plan

None - plan executed exactly as written.

## Decisions Made

1. **Kept KeyboardShortcuts.Name declarations**: The Recorder API requires a `Name` parameter. Instead of removing declarations, used `KeyboardShortcuts.disable()` to prevent the framework from intercepting keystrokes while keeping the recorder UI functional.

## Verification

- Build: clean success (5.87s)
- All 5 grep checks confirmed wiring is in place

## Requirements Satisfied

- HOTKEY-03: loadSettings(from:) called at startup, modifiers applied
- LLM-03: LLM download progress rendered in StatusItemView
- UI-04: recordingState resets to .idle on any sheet dismiss
- DEBUG-02: DebugArchiver.save() called in both normal and confirm paths
