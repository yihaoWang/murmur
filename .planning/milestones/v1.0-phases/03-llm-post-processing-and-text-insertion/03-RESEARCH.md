# Phase 3: LLM Post-Processing and Text Insertion - Research

**Researched:** 2026-03-17
**Domain:** MLX Swift LLM inference + macOS Accessibility API text insertion
**Confidence:** MEDIUM (MLX Swift LM API verified via official README; AX insertion patterns verified via multiple sources; TransientType spec verified via nspasteboard.org)

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| LLM-01 | Post-process transcribed text using MLX Swift with Qwen3-1.7B model | `mlx-swift-lm` 2.30.6, `loadModel` + `ChatSession` API confirmed |
| LLM-02 | Format text according to TC conventions (no spaces between characters) | Prompt engineering; Qwen3 natively understands Traditional Chinese |
| LLM-03 | Download LLM model on first launch with progress indicator | `ModelManager` actor pattern already established in project; mlx-swift-lm uses HuggingFace Hub download which needs wrapping for progress |
| INSERT-01 | Insert text at cursor position via macOS Accessibility API (AXUIElement) | `kAXSelectedTextAttribute` set via `AXUIElementSetAttributeValue`; primary path for native apps |
| INSERT-02 | Fall back to clipboard paste when AX insertion fails (Electron, Terminal) | Detect `AXError` != `.success`; simulate Cmd+V via `CGEventPost` |
| INSERT-03 | Save and restore clipboard contents around paste fallback | `NSPasteboard.general` read before, restore after |
| INSERT-04 | Use NSPasteboard TransientType marker | `org.nspasteboard.TransientType` marker on write; honored by Maccy and other managers |
</phase_requirements>

---

## Summary

Phase 3 has two distinct technical domains. The first is LLM post-processing: load Qwen3-1.7B-4bit from HuggingFace via `mlx-swift-lm`, run a single-turn formatting prompt, and return the result. The second is text insertion: attempt `kAXSelectedTextAttribute` write via the Accessibility API, and fall back to clipboard paste with Cmd+V simulation when the AX path returns an error.

The key blocker from STATE.md — "mlx-swift-lm 2.30.6 API surface needs verification" — is now largely resolved. The confirmed API is `loadModel(id:)` returning an opaque model handle, and `ChatSession(model)` with `session.respond(to:)`. The `LLMModelFactory.shared.loadContainer()` is the lower-level path for progress reporting during model load; the `loadModel` convenience wrapper does not expose incremental progress, so the planner must decide which to use (see Open Questions).

The AX insertion path is well-understood. `AXUIElementSetAttributeValue` on `kAXSelectedTextAttribute` works in native AppKit/NSTextField controls. It silently fails (returns non-success `AXError`) in Electron apps and Terminal. The fallback is: copy text to pasteboard with `TransientType` marker, synthesize `⌘V` via `CGEventPost`, then restore the pasteboard from the saved snapshot.

**Primary recommendation:** Use `LLMModelFactory.shared.loadContainer()` for model loading (to get progress), then wrap in a `PostProcessingEngine` actor parallel to the existing `TranscriptionEngine` actor. Use a `TextInsertionEngine` struct with a two-path `insert(_:)` method that returns whether AX or clipboard path was used.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mlx-swift-lm | 2.30.6 | On-device LLM inference (Qwen3) | Official Apple Silicon MLX framework; chosen in project decisions |
| ApplicationServices (system) | macOS 14+ | AX text insertion via AXUIElement | System framework; no alternative for cross-app text injection |
| AppKit (system) | macOS 14+ | NSPasteboard clipboard operations | System framework |
| CoreGraphics (system) | macOS 14+ | CGEventPost for Cmd+V simulation | System framework; needed for fallback paste |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| MLXLMCommon | bundled with mlx-swift-lm | Shared types (ModelConfiguration, UserInput) | Always — dependency of mlx-swift-lm |
| MLXNN | bundled with mlx-swift | Neural network layers | Indirect — pulled in by mlx-swift-lm |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| mlx-swift-lm ChatSession | Core ML + Create ML | Core ML lacks Qwen3 support out of box; mlx-swift-lm is the locked decision |
| CGEventPost Cmd+V | AXDoAction kAXPressAction | AXDoAction on paste menu item is fragile; CGEventPost is widely used pattern |

**Installation — add to Package.swift:**
```swift
.package(url: "https://github.com/ml-explore/mlx-swift-lm/", .upToNextMinor(from: "2.29.1"))
```
In target dependencies:
```swift
.product(name: "LLM", package: "mlx-swift-lm"),
.product(name: "MLXLMCommon", package: "mlx-swift-lm"),
```

Note: The latest release tag is 2.30.6 (February 2026). The `.upToNextMinor(from: "2.29.1")` declaration in the official README will resolve to 2.30.6. Pin to `.exact("2.30.6")` for reproducibility if desired.

---

## Architecture Patterns

### Recommended Project Structure Additions
```
Typeness/
├── Core/
│   ├── PostProcessingEngine.swift   # actor — LLM inference wrapper
│   └── TextInsertionEngine.swift    # struct — AX + clipboard fallback
├── App/
│   └── TypenessApp.swift            # wire PostProcessingEngine into pipeline
```

New files parallel the Phase 2 pattern (`TranscriptionEngine` actor, `AudioCaptureEngine` actor). This keeps each concern isolated and testable.

### Pattern 1: PostProcessingEngine actor
**What:** An actor that holds the loaded MLX model and exposes a single `format(_:)` method.
**When to use:** Any time transcription output needs formatting before insertion.
**Example:**
```swift
// Source: mlx-swift-lm README (verified 2026-03-17)
import LLM
import MLXLMCommon

actor PostProcessingEngine {
    private var model: ModelContainer?

    /// Load the Qwen3-1.7B-4bit model. Reports progress [0.0, 1.0] via the closure.
    func load(onProgress: @escaping (Double) -> Void) async throws {
        // LLMModelFactory.shared.loadContainer gives granular progress;
        // use ModelConfiguration for the local/hub model ID
        let config = ModelConfiguration(id: "mlx-community/Qwen3-1.7B-4bit")
        model = try await LLMModelFactory.shared.loadContainer(
            configuration: config,
            progressHandler: { progress in
                onProgress(progress.fractionCompleted)
            }
        )
    }

    /// Format raw Whisper output for Traditional Chinese conventions.
    func format(_ rawText: String) async throws -> String {
        guard let model else { throw PostProcessingError.notLoaded }
        let prompt = """
            你是一個文字格式化助手。將以下語音辨識文字加上正確的中文標點符號，不要在中文字之間加空格，不要更改內容。只輸出格式化後的文字。
            輸入：\(rawText)
            輸出：
            """
        let result = try await model.perform { [prompt] context in
            let session = ChatSession(context)
            return try await session.respond(to: prompt)
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PostProcessingError: Error {
    case notLoaded
}
```

Note: `model.perform { context in ... }` is the thread-safe pattern for `ModelContainer`. Verify exact closure signature against mlx-swift-lm 2.30.6 source (see Open Questions).

### Pattern 2: TextInsertionEngine — AX primary, clipboard fallback
**What:** A struct with a single `insert(_:)` method that tries AX insertion first.
**When to use:** Any time formatted text must be placed at the cursor.
**Example:**
```swift
// Source: AX API documented at developer.apple.com + community verification 2026
import ApplicationServices
import AppKit

struct TextInsertionEngine {
    enum InsertionPath {
        case accessibility
        case clipboardPaste
    }

    @discardableResult
    func insert(_ text: String) -> InsertionPath {
        if tryAccessibilityInsert(text) {
            return .accessibility
        }
        clipboardPasteInsert(text)
        return .clipboardPaste
    }

    // MARK: - AX Path

    private func tryAccessibilityInsert(_ text: String) -> Bool {
        var focusedElement: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement else { return false }

        let result = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }

    // MARK: - Clipboard Fallback Path

    private func clipboardPasteInsert(_ text: String) {
        let pasteboard = NSPasteboard.general

        // 1. Snapshot current clipboard
        let savedContents = snapshotPasteboard(pasteboard)

        // 2. Write with TransientType marker
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        // TransientType marker: clipboard history managers must not record this
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))

        // 3. Synthesize Cmd+V
        let vKeyCode: CGKeyCode = 9
        let cmdV = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true)
        cmdV?.flags = .maskCommand
        cmdV?.post(tap: .cghidEventTap)
        let cmdVUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false)
        cmdVUp?.flags = .maskCommand
        cmdVUp?.post(tap: .cghidEventTap)

        // 4. Restore clipboard after short delay (paste must complete first)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            restorePasteboard(pasteboard, from: savedContents)
        }
    }

    private func snapshotPasteboard(_ pb: NSPasteboard) -> [(NSPasteboard.PasteboardType, Data)] {
        var result: [(NSPasteboard.PasteboardType, Data)] = []
        for item in pb.pasteboardItems ?? [] {
            for type in item.types {
                if let data = item.data(forType: type) {
                    result.append((type, data))
                }
            }
        }
        return result
    }

    private func restorePasteboard(_ pb: NSPasteboard, from snapshot: [(NSPasteboard.PasteboardType, Data)]) {
        pb.clearContents()
        if snapshot.isEmpty { return }
        let item = NSPasteboardItem()
        for (type, data) in snapshot {
            item.setData(data, forType: type)
        }
        pb.writeObjects([item])
    }
}
```

### Pattern 3: LLM-03 model download progress integration
The existing `ModelManager` actor tracks `isWhisperModelReady`. Extend it with `isLLMModelReady` and `llmDownloadProgress`, reporting through `AppState`. The mlx-swift-lm `loadContainer(configuration:progressHandler:)` callback drives these values.

```swift
// In ModelManager:
func downloadAndLoadLLMIfNeeded(appState: AppState) async throws -> ModelContainer {
    let config = ModelConfiguration(id: "mlx-community/Qwen3-1.7B-4bit")
    return try await LLMModelFactory.shared.loadContainer(
        configuration: config,
        progressHandler: { progress in
            Task { @MainActor in
                appState.llmDownloadProgress = progress.fractionCompleted
            }
        }
    )
}
```

New `AppState` properties needed: `isLLMModelReady: Bool`, `llmDownloadProgress: Double?`.

### Anti-Patterns to Avoid
- **Setting `kAXValueAttribute` instead of `kAXSelectedTextAttribute`:** Setting `kAXValueAttribute` replaces all text in a field rather than inserting at the cursor. Only use `kAXSelectedTextAttribute`.
- **Not restoring the pasteboard:** Leaving temp text in the clipboard is bad UX. Always restore in the fallback path.
- **Calling `respond(to:)` from the main thread:** MLX inference is CPU/GPU intensive. Always `await` inside an actor or `Task.detached`.
- **Blocking on model load:** The 968 MB Qwen3-1.7B-4bit model download must show progress (LLM-03). Do not use `loadModel(id:)` bare — it does not expose progress.
- **Long prompt for formatting:** The formatting prompt should be minimal. A verbose system prompt increases token count and latency for a 1.7B model. Keep it under 100 tokens.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| LLM inference on Apple Silicon | Custom Metal shaders, Core ML pipeline | mlx-swift-lm | MLX handles quantization, KV cache, Metal dispatch |
| HuggingFace model download | Custom URLSession with shard tracking | LLMModelFactory.shared.loadContainer | Model shards, hash verification, cache management |
| Tokenization for Qwen3 | Byte-pair encoding impl | mlx-swift-lm tokenizer (bundled) | Qwen3 uses tiktoken-based BPE; subtle edge cases |
| Clipboard history suppression | Custom clipboard monitor protocol | `org.nspasteboard.TransientType` marker | Established ecosystem standard; Maccy, Pasta, etc. honor it |

**Key insight:** The clipboard and LLM problems each have established, tested solutions. Any custom implementation will miss edge cases (model shard verification, clipboard type preservation across apps) that the existing solutions already handle.

---

## Common Pitfalls

### Pitfall 1: `AXUIElementSetAttributeValue` returns `.success` but text is not inserted
**What goes wrong:** Electron apps (VS Code, Slack) and some web views return `.success` from `AXUIElementSetAttributeValue` but do not actually insert text. The AX path silently "succeeds" without effect.
**Why it happens:** Electron implements a partial AX API; it accepts the attribute set call without routing it to the document model.
**How to avoid:** The project has already decided (roadmap success criteria) that Electron apps use the clipboard fallback. However, detecting the silent-success case is hard. A practical heuristic: read `kAXSelectedTextAttribute` back immediately after setting it and compare. If the text is not present, fall back. This adds a read round-trip.
**Warning signs:** User reports text not appearing in VS Code or Slack.

### Pitfall 2: mlx-swift-lm `loadModel` vs `LLMModelFactory.shared.loadContainer` API confusion
**What goes wrong:** `loadModel(id:)` is a convenience function that does not expose download progress. `LLMModelFactory.shared.loadContainer(configuration:progressHandler:)` is the full API with progress. Using `loadModel` means no progress indicator for LLM-03.
**Why it happens:** The README shows the simple API first; the progress API requires more setup.
**How to avoid:** Use `LLMModelFactory.shared.loadContainer` in `ModelManager`. Verify exact method signature against source at tag 2.30.6 before coding.
**Warning signs:** Progress bar stays at 0% during model download.

### Pitfall 3: Clipboard restore races with paste completion
**What goes wrong:** Restoring the clipboard before the target app has completed the paste operation results in pasting the original clipboard contents instead of the transcription.
**Why it happens:** `CGEventPost` is asynchronous — the event is queued, not executed immediately. A 0ms restore will often race.
**How to avoid:** Use `asyncAfter(deadline: .now() + 0.15)` (150ms delay). This is the community-standard delay. It is a heuristic, not guaranteed.
**Warning signs:** Clipboard paste inserts old clipboard contents instead of transcription.

### Pitfall 4: NSPasteboard TransientType does not work with all clipboard managers
**What goes wrong:** Some clipboard managers do not honor `org.nspasteboard.TransientType`. Older or less-maintained managers may still capture the temporary paste content.
**Why it happens:** The TransientType spec is a convention, not an OS enforcement. Apps must opt in to honor it.
**How to avoid:** Use the marker (it works for Maccy and other popular managers) and document as a known limitation (per STATE.md blocker).
**Warning signs:** Clipboard history shows single-character or partial transcription strings.

### Pitfall 5: Qwen3 thinking mode tokens in output
**What goes wrong:** Qwen3 models can emit `<think>...</think>` reasoning tokens before the actual output. These would appear in the inserted text.
**Why it happens:** Qwen3 has a "thinking mode" that can be toggled. At 1.7B size the model may still emit partial think tokens.
**How to avoid:** Strip content between `<think>` and `</think>` tags from the model output before insertion. Add a no-thinking instruction to the prompt: append `/no_think` or set `enable_thinking: false` in generation parameters if mlx-swift-lm exposes this. Verify against model card.
**Warning signs:** Inserted text contains `<think>` or partial XML-like tags.

---

## Code Examples

### NSPasteboard TransientType write
```swift
// Source: nspasteboard.org specification (verified 2026-03-17)
let pasteboard = NSPasteboard.general
pasteboard.clearContents()
pasteboard.setString(text, forType: .string)
pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
```

### AX focused element insert
```swift
// Source: Apple Developer Documentation kAXSelectedTextAttribute + community patterns
var focusedElement: CFTypeRef?
let systemWide = AXUIElementCreateSystemWide()
let err = AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement)
if err == .success, let element = focusedElement {
    let setErr = AXUIElementSetAttributeValue(
        element as! AXUIElement,
        kAXSelectedTextAttribute as CFString,
        text as CFTypeRef
    )
    // setErr == .success = inserted; anything else = fallback
}
```

### CGEventPost Cmd+V
```swift
// Source: Apple CoreGraphics documentation + community patterns
let vKey: CGKeyCode = 9  // kVK_ANSI_V
func postCmdV() {
    let down = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: true)
    down?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    let up = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: false)
    up?.flags = .maskCommand
    up?.post(tap: .cghidEventTap)
}
```

### mlx-swift-lm SPM + loadContainer
```swift
// Source: mlx-swift-lm README (verified 2026-03-17) + API pattern
// Package.swift:
.package(url: "https://github.com/ml-explore/mlx-swift-lm/", .upToNextMinor(from: "2.29.1"))

// Usage:
import LLM
import MLXLMCommon

let config = ModelConfiguration(id: "mlx-community/Qwen3-1.7B-4bit")
let container: ModelContainer = try await LLMModelFactory.shared.loadContainer(
    configuration: config,
    progressHandler: { progress in
        // progress.fractionCompleted: Double in [0.0, 1.0]
    }
)
let result: String = try await container.perform { context in
    let session = ChatSession(context)
    return try await session.respond(to: prompt)
}
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `loadModelContainer()` | `LLMModelFactory.shared.loadContainer()` | mlx-swift-lm 2.x refactor | Factory method now on LLMModelFactory |
| Manual NSPasteboard loop for snapshot | Item-by-item `pasteboardItems` snapshot | macOS 10.6+ | Multi-type clipboard items properly preserved |

**Deprecated/outdated:**
- `loadModelContainer()` top-level function: replaced by `LLMModelFactory.shared.loadContainer()` — do not use.
- `TextExpander`'s proprietary `de.petermaurer.TransientPasteboardType`: superseded by `org.nspasteboard.TransientType` — use the standard marker; can add the legacy one too for old manager compat, but not required.

---

## Open Questions

1. **`LLMModelFactory.shared.loadContainer` exact method signature in 2.30.6**
   - What we know: The conceptual API is `loadContainer(configuration:progressHandler:)` returning `ModelContainer`.
   - What's unclear: Whether `progressHandler` is a `Progress` callback or `Double` callback; whether `ModelContainer.perform` takes a closure or has a different name at this version.
   - Recommendation: Before writing `PostProcessingEngine`, fetch the actual Swift source at tag 2.30.6: `https://raw.githubusercontent.com/ml-explore/mlx-swift-lm/2.30.6/Sources/LLM/LLMModelFactory.swift`. Do this in Wave 0 of the plan.

2. **Electron silent-success detection strategy**
   - What we know: VS Code, Slack return `.success` from AX but do not insert.
   - What's unclear: Whether a post-set read reliably detects this without false positives in edge cases.
   - Recommendation: Implement AX path first; if post-set read verification is too costly, accept that Electron will need an explicit app bundle ID denylist (detect frontmost app and skip AX for known Electron bundles).

3. **Qwen3-1.7B-4bit thinking mode behavior**
   - What we know: Qwen3 has a thinking mode. The 1.7B model card recommends `/no_think` for non-reasoning tasks.
   - What's unclear: Whether mlx-swift-lm exposes a `thinking: false` generation parameter or whether prompt engineering alone is sufficient.
   - Recommendation: Include `<|think|>` token stripping as a safety net regardless; also verify Qwen3's no-think prompt format.

4. **LLM model download path with mlx-swift-lm**
   - What we know: `LLMModelFactory.shared.loadContainer` downloads model files from HuggingFace Hub to a cache directory.
   - What's unclear: Exact cache location (is it `~/Library/Application Support` like the project's whisper model, or `~/.cache/huggingface`?). This matters for `llmModelDirectory()` in `ModelManager`.
   - Recommendation: The planner should include a Wave 0 task to `print` the resolved model directory from a test run, then update `ModelManager.llmModelDirectory()` accordingly.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | XCTest (existing) |
| Config file | Typeness.xcodeproj test target TypenessTests |
| Quick run command | `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/PostProcessingTests 2>&1 | tail -20` |
| Full suite command | `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 | tail -40` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| LLM-01 | `PostProcessingEngine.format(_:)` throws `.notLoaded` when model not loaded | unit | `xcodebuild test ... -only-testing TypenessTests/PostProcessingTests/testFormatThrowsWhenNotLoaded` | ❌ Wave 0 |
| LLM-02 | Output contains no spaces between Chinese characters (regex check on known input) | unit | `xcodebuild test ... -only-testing TypenessTests/PostProcessingTests/testNoSpacesBetweenChineseChars` | ❌ Wave 0 |
| LLM-03 | Progress callback is called with values in [0.0, 1.0] | integration/manual | XCTSkip (requires network + 968 MB download) | ❌ Wave 0 |
| INSERT-01 | `TextInsertionEngine` returns `.accessibility` when AX set succeeds (mock AX) | unit | XCTSkip (requires real focused AX element) | ❌ Wave 0 |
| INSERT-02 | `TextInsertionEngine` returns `.clipboardPaste` when AX set fails | unit | XCTSkip (hard to mock) | ❌ Wave 0 |
| INSERT-03 | Clipboard is restored to original content after paste fallback | unit | `xcodebuild test ... -only-testing TypenessTests/TextInsertionTests/testClipboardRestored` | ❌ Wave 0 |
| INSERT-04 | NSPasteboard write includes `org.nspasteboard.TransientType` type | unit | `xcodebuild test ... -only-testing TypenessTests/TextInsertionTests/testTransientTypeMarkerPresent` | ❌ Wave 0 |

Note: AX insertion tests (INSERT-01, INSERT-02) require a real focused text element and cannot be meaningfully unit-tested without a live UI. Use `XCTSkip` stubs that document the manual test procedure.

### Sampling Rate
- **Per task commit:** `xcodebuild test -scheme Typeness -destination 'platform=macOS' -only-testing TypenessTests/PostProcessingTests -only-testing TypenessTests/TextInsertionTests 2>&1 | tail -20`
- **Per wave merge:** Full suite: `xcodebuild test -scheme Typeness -destination 'platform=macOS' 2>&1 | tail -40`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `Tests/TypenessTests/PostProcessingTests.swift` — covers LLM-01, LLM-02 stubs
- [ ] `Tests/TypenessTests/TextInsertionTests.swift` — covers INSERT-03, INSERT-04 (clipboard path); INSERT-01/02 as XCTSkip stubs
- [ ] Verify mlx-swift-lm 2.30.6 exact API surface from source (fetch `LLMModelFactory.swift`)

---

## Sources

### Primary (HIGH confidence)
- mlx-swift-lm GitHub README (verified 2026-03-17) — `loadModel`, `ChatSession`, `respond`, SPM declaration, version 2.30.6
- nspasteboard.org specification (verified 2026-03-17) — `org.nspasteboard.TransientType` exact string, semantics, implementation guidelines
- Apple Developer Documentation — `kAXSelectedTextAttribute`, `AXUIElementSetAttributeValue`, `AXUIElementCreateSystemWide`
- HuggingFace mlx-community/Qwen3-1.7B-4bit model card (verified 2026-03-17) — model size 968 MB, quantization 4-bit, model ID confirmed

### Secondary (MEDIUM confidence)
- WebSearch result: mlx-swift-lm ChatSession code example (multiple corroborating sources)
- WebSearch result: AX text insertion patterns, Electron AX limitations (Electron issue #36337 corroborates Electron AX partial support)
- Maccy source (GitHub p0deje/Maccy) — confirms `org.nspasteboard.TransientType` is honored and filtered from history

### Tertiary (LOW confidence)
- 150ms clipboard restore delay: community convention without official source; used widely in similar tools

---

## Metadata

**Confidence breakdown:**
- Standard stack: MEDIUM — mlx-swift-lm API confirmed from README but exact `loadContainer` signature at 2.30.6 needs source verification
- Architecture: MEDIUM — patterns follow established project conventions (actor per concern); AX insertion is well-documented; clipboard pattern is community-validated
- Pitfalls: HIGH — Electron AX silent-success is a documented bug; TransientType behavior documented officially; Qwen3 thinking tokens noted in model documentation

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (mlx-swift-lm releases frequently; re-verify API if > 30 days)
