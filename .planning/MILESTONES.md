# Milestones

## v1.0 MVP (Shipped: 2026-03-17)

**Phases completed:** 5 phases, 15 plans
**Timeline:** 2026-03-16 → 2026-03-17 (1 day)
**Source:** 1,160 LOC Swift

**Key accomplishments:**
- Menu bar app shell with SwiftUI settings, permissions onboarding, and global CGEventTap hotkeys
- 16kHz audio capture with AVAudioEngine resampling and whisper.cpp CoreML/Accelerate transcription
- Qwen3-1.7B LLM post-processing for Traditional Chinese punctuation via MLX Swift
- Dual-path text insertion (Accessibility API primary, clipboard paste fallback with TransientType)
- Full pipeline wiring with debug archiving, confirm-before-insert, and dynamic menu bar status icons
- Gap closure: hotkey modifier sync, LLM progress display, confirm-mode state management

**Tech debt accepted:**
- Hotkey settings require app restart to take effect (no live reload)
- StatusItemView creates fresh TextInsertionEngine in confirm callback
- ModelManager.downloadAndLoadLLMIfNeeded() orphaned dead code

---

