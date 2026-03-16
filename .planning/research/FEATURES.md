# Feature Research

**Domain:** macOS voice-to-text / dictation input tools
**Researched:** 2026-03-16
**Confidence:** HIGH (multiple current sources, competitor feature analysis, user feedback)

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Global hotkey activation | Core UX — dictation must be available in any app without switching focus | LOW | Toggle and push-to-talk are both expected; push-to-talk feels more immediate |
| Works in any app | Voice-to-text is useless if locked to one window | MEDIUM | Requires Accessibility API or clipboard fallback; Accessibility API preferred (no clipboard flash) |
| Text inserted at cursor | Users expect text to appear where they are typing, not in a separate field | MEDIUM | Accessibility API primary, clipboard paste fallback for apps that block AX |
| Menu bar presence | All third-party macOS dictation tools use menu bar; LSUIElement pattern expected | LOW | Dock presence feels wrong for a background input tool |
| Visual recording indicator | Users need feedback that the mic is active; lack of indicator causes confusion and re-recording | LOW | Floating overlay, menu bar icon change, or both |
| Transcription accuracy | App is useless if transcription is bad; users will immediately abandon | HIGH | Whisper large-v3-turbo is current standard for local quality |
| Offline / local processing | Privacy concern is primary for power users; cloud-based is a non-starter for many | HIGH | This is table stakes for the Whisper-based segment specifically |
| Low latency response | Users expect text within 1-2 seconds of stopping speech; longer = frustrating | HIGH | Metal GPU acceleration is required; CPU-only Whisper is too slow |
| Settings UI | Hotkey customization, model selection, and behavior settings are always exposed | MEDIUM | SwiftUI popover or preferences window |
| Auto-start at login | Tool must be available without manual launch | LOW | LaunchAgent or Login Items; macOS 13+ Login Items API preferred |
| Silence detection / auto-stop | Users expect recording to stop when they stop speaking, not require manual stop | MEDIUM | Energy-based VAD or WebRTC VAD; avoids "still recording" confusion |
| Microphone permission handling | macOS requires explicit permission; apps must handle denied/undetermined states gracefully | LOW | Clear prompt + fallback UI if denied |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| LLM post-processing for punctuation/formatting | Raw Whisper output lacks punctuation for Chinese; LLM cleanup makes output paste-ready | HIGH | Already in Python version; Qwen3-1.7B via MLX Swift. This is a real differentiator — most tools don't do this for CJK |
| Traditional Chinese specialization | Most tools are English-first; accurate TC with correct punctuation (，。！？) is a genuine gap | HIGH | Whisper large-v3-turbo has strong TC support; LLM post-processing handles TC-specific formatting conventions |
| Confirm-before-insert mode | Users composing careful messages (legal, medical, formal) want to review before text lands | LOW | Simple overlay with approve/cancel; reduces fear of "wrong text inserted" |
| Context-aware text insertion | Reading selected text or clipboard before transcription allows LLM to continue/reply in context | HIGH | Superwhisper's top differentiator per user research; requires AX API to read selection |
| Debug / recording archive | Developers and power users want WAV + JSON exports for diagnosing transcription errors | LOW | Already in Python version; save to ~/Library/Application Support |
| Multiple hotkey modes | Different bindings for toggle vs push-to-talk gives flexibility for different workflows | LOW | Already in Python version; both modes on separate keys |
| Model size selection | Users can trade accuracy for speed (nano vs large); power users want control | MEDIUM | Requires model download management UI |
| Custom vocabulary / word substitutions | Technical terms, names, brand words that Whisper consistently mishears | MEDIUM | Post-processing substitution table; simpler than fine-tuning |
| Floating transcription preview | Show live or post-transcription text in a floating window before insertion | MEDIUM | Useful for long dictations; lets user verify before paste |
| Per-app mode profiles | Different formatting behavior for Slack vs Terminal vs email | HIGH | Superwhisper's "modes" feature; complex to build correctly |
| Translation mode | Speak one language, insert another | MEDIUM | Whisper supports translate task natively; useful for TC → EN |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| Cloud-based transcription option | Higher accuracy for some languages, no local GPU needed | Destroys privacy guarantee; adds network dependency; adds subscription complexity; contradicts core value | Commit to local-only; invest in on-device model quality instead |
| Always-on ambient listening | "Just start talking" without pressing a key | macOS mic permission UI will show continuous mic usage, alarming users; high privacy concern; unpredictable activation | Explicit push-to-talk or toggle; makes activation intentional and trustworthy |
| Transcription history / cloud sync | Users want to search past dictations | Storing voice transcripts creates privacy liability; syncing requires backend; out of scope for v1 | Local-only debug log (already planned) satisfies the power user need |
| Built-in note-taking or document editor | Capture ideas directly in the app | Scope creep; competes with every editor; Typeness is an input layer, not an editor | Work with existing editors; insert text into whatever the user already uses |
| Real-time streaming transcription display | Watch words appear as you speak | Increases architectural complexity significantly; Whisper is not designed for streaming (it's a batch model); false starts clutter output | Single-pass transcription after recording stops; fast enough with GPU acceleration |
| iOS / iPadOS companion app | Users want dictation on all devices | Entirely separate codebase; App Store distribution complexity; different use cases; dilutes focus | macOS-only v1; mobile is a separate product decision |
| App Store distribution | Wider reach, easier updates | Hardened runtime + sandbox restrictions make Accessibility API and LaunchAgent complex; additional review overhead | Direct distribution (already decided); Sparkle for updates |
| Subscription pricing model | Recurring revenue | Users in this segment (privacy-first, local-only) strongly prefer one-time purchase; subscription = distrust | One-time purchase or free/open source; monetize through paid upgrades |

## Feature Dependencies

```
[Audio Recording]
    └──requires──> [Microphone Permission]
    └──requires──> [Global Hotkey]

[Transcription (Whisper)]
    └──requires──> [Audio Recording]
    └──requires──> [whisper.cpp model downloaded]

[LLM Post-Processing]
    └──requires──> [Transcription (Whisper)]
    └──requires──> [MLX model downloaded]

[Text Insertion at Cursor]
    └──requires──> [Transcription (Whisper)]
    └──optional──> [LLM Post-Processing]
    └──requires──> [Accessibility API permission OR clipboard fallback]

[Confirm-Before-Insert]
    └──requires──> [Transcription complete]
    └──enhances──> [Text Insertion at Cursor]

[Debug Mode]
    └──requires──> [Audio Recording]
    └──enhances──> [Transcription (Whisper)]

[Context-Aware Insertion]
    └──requires──> [Accessibility API permission]
    └──enhances──> [LLM Post-Processing]

[Model Download Manager]
    └──requires──> [Settings UI]
    └──blocks──> [Transcription (Whisper)] until model present
    └──blocks──> [LLM Post-Processing] until model present

[Auto-Start at Login]
    └──requires──> [Settings UI]

[Custom Vocabulary]
    └──enhances──> [LLM Post-Processing] or [Transcription post-step]
```

### Dependency Notes

- **Text Insertion requires Accessibility permission:** macOS requires explicit user grant for AX API; clipboard fallback works without it but is visually disruptive (clipboard changes, paste animation)
- **Model Download blocks recording:** First-launch experience must guide user through model download before any transcription is possible; progress UI is required
- **LLM Post-Processing is optional path:** Transcription can insert raw Whisper output if LLM is unavailable/loading; graceful degradation matters
- **Context-Aware Insertion requires AX:** Reading the selected text in the target app requires the same Accessibility permission already needed for text insertion; no additional permission needed

## MVP Definition

### Launch With (v1)

Minimum viable product — feature parity with existing Python version.

- [ ] Global hotkey: toggle mode (Shift+Cmd+A) — core activation mechanism
- [ ] Global hotkey: push-to-talk (Option+Space) — faster mode for short inputs
- [ ] Audio recording at 16kHz mono — correct sample rate for Whisper
- [ ] Whisper transcription via whisper.cpp with Metal GPU acceleration — table stakes accuracy
- [ ] LLM post-processing via MLX Swift (Qwen3-1.7B) — TC punctuation/formatting; key differentiator
- [ ] Text insertion via Accessibility API with clipboard fallback — universal app compatibility
- [ ] Menu bar app (LSUIElement) with SwiftUI popover — expected UI pattern
- [ ] Visual recording indicator (menu bar icon state) — prevents "still recording?" confusion
- [ ] Settings: hotkey configuration, confirm-before-insert, debug mode, auto-start — required for daily use
- [ ] Auto-start at login via LaunchAgent — tool must survive reboots
- [ ] Model download + progress UI — first-launch must work without manual model management
- [ ] Debug mode: save WAV + JSON — power user requirement, low complexity

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Confirm-before-insert overlay — add when user feedback shows insertion errors are a pain point
- [ ] Custom vocabulary / substitution table — add when users report recurring name/term errors
- [ ] Silence detection / auto-stop — add when users report "forgot to stop recording" as friction
- [ ] Translation mode (TC → EN) — add when multilingual use cases confirmed
- [ ] Floating transcription preview — add when long-dictation use cases confirmed

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Context-aware insertion (read selected text for LLM context) — high complexity, requires careful UX design
- [ ] Per-app mode profiles — significant complexity; validate demand first
- [ ] Multiple language support — TC-first is correct; add languages based on user demand
- [ ] Model size selection UI — add when user base includes both low-end and high-end Apple Silicon

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Global hotkey (toggle + PTT) | HIGH | LOW | P1 |
| Whisper transcription (Metal) | HIGH | HIGH | P1 |
| Text insertion (AX API) | HIGH | MEDIUM | P1 |
| LLM post-processing (TC formatting) | HIGH | HIGH | P1 |
| Menu bar app + visual indicator | HIGH | LOW | P1 |
| Model download manager | HIGH | MEDIUM | P1 |
| Settings UI | HIGH | MEDIUM | P1 |
| Auto-start at login | MEDIUM | LOW | P1 |
| Debug mode | MEDIUM | LOW | P1 |
| Confirm-before-insert | MEDIUM | LOW | P2 |
| Silence detection / auto-stop | MEDIUM | MEDIUM | P2 |
| Custom vocabulary | MEDIUM | MEDIUM | P2 |
| Translation mode | LOW | LOW | P2 |
| Context-aware insertion | HIGH | HIGH | P3 |
| Per-app mode profiles | MEDIUM | HIGH | P3 |

**Priority key:**
- P1: Must have for launch (feature parity with Python version)
- P2: Should have, add when core is stable
- P3: Nice to have, future consideration

## Competitor Feature Analysis

| Feature | Superwhisper | Wispr Flow | Sotto | Typeness (Python) | Our Approach |
|---------|--------------|------------|-------|-------------------|--------------|
| Local/offline processing | Yes | No (cloud) | Yes | Yes | Yes — core constraint |
| Global hotkey | Yes | Yes | Yes | Yes (2 modes) | Yes (toggle + PTT) |
| Push-to-talk | Yes | Yes | Yes | Yes | Yes |
| LLM post-processing | Yes (via external API) | Yes (cloud) | No | Yes (local LLM) | Yes — local Qwen3 |
| Traditional Chinese | Yes (multilingual) | Yes (multilingual) | Unknown | Yes (specialized) | Yes — primary focus |
| Confirm-before-insert | No | No | No | Yes | Yes |
| Custom vocabulary | Yes | Yes | Yes | No | P2 |
| Context-aware (reads screen) | Yes (Super Mode) | No | No | No | P3 |
| Menu bar app | Yes | Yes | Yes | Yes | Yes |
| Pricing | Subscription | Subscription | One-time $49 | Free/personal | TBD |
| Open source | No | No | No | Yes (Python) | TBD |

## Sources

- [Choosing the Right AI Dictation App for Mac: The True Differentiators](https://afadingthought.substack.com/p/best-ai-dictation-tools-for-mac) — MEDIUM confidence, single analyst source but well-reasoned
- [Superwhisper feature overview](https://superwhisper.com/) — HIGH confidence, official source
- [Sotto dictation app comparison 2025](https://sotto.to/blog/dictation-app-comparison-2025) — MEDIUM confidence, competitor source
- [Best Mac Voice Dictation Software 2025](https://willowvoice.com/blog/best-voice-dictation-software-mac) — MEDIUM confidence
- [Super Whisper vs Wispr Flow comparison](https://willowvoice.com/blog/super-whisper-vs-wispr-flow-comparison-reviews-and-alternatives-in-2025) — MEDIUM confidence
- Python version requirements (PROJECT.md) — HIGH confidence, direct source

---
*Feature research for: macOS voice-to-text / dictation input tools*
*Researched: 2026-03-16*
