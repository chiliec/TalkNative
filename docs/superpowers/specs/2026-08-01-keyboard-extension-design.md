# TalkNative — Keyboard Extension (Design Spec)

**Date:** 2026-08-01
**Status:** Approved for implementation planning
**Amends:** `2026-04-18-talknative-design.md`
**Supersedes:** the deferred "Action extension" work item (v1.1)

## Summary

TalkNative gains a **custom keyboard extension** that rewrites text in place inside any app. The user selects text (or relies on what they just typed), switches to the TalkNative keyboard with the globe key, taps one of three streamed variants, and the text is replaced directly in the host app's field via `UITextDocumentProxy`.

This replaces the Action extension planned for v1.1. That plan rested on a mechanism that does not work — see *Why not an Action extension* below.

The keyboard is a **utility panel, not a QWERTY replacement**: it contains no letter keys. It reuses `Enhancer`, `EnhancementViewModel`, and the existing preset model unchanged, and adds two packages plus one thin extension target.

## Motivation

1. **The v1 promise is unfulfilled.** `2026-04-18-talknative-design.md` §"Invocation surfaces" promises in-place replacement. The Share extension delivers copy-to-clipboard; the user still pastes manually. This is the gap.
2. **A keyboard is the only mechanism that works.** iOS provides no general "write to the focused text field" API. `UITextDocumentProxy` is the sole route into arbitrary third-party apps.
3. **The seams already exist.** `VariantCard.ActionKind.useThis`, `ResultSheet(variantAction:)`, and `ExtensionMode.action` were all built in v1 and are currently dead code — `ShareViewController.swift:41` passes `onUseAndReturn` as a no-op. This spec activates them.

## Why not an Action extension

The v1 spec states (line 29): *"tapping one replaces the selected text in place via `NSExtensionContext.completeRequest`."* This is not achievable on iOS.

Returning an `NSExtensionItem` from an Action extension only has an effect if the **host app** implements `completionWithItemsHandler` on its `UIActivityViewController`. Notes, Mail, Messages, Safari text fields, and effectively all third-party apps do not. The returned string is silently discarded.

Scoped alternatives, and why each is insufficient alone:

| Mechanism | Reach | Verdict |
|---|---|---|
| `UITextDocumentProxy` (keyboard) | Any app | **Chosen** |
| `MSConversation.insertText(_:)` | Messages only | Too narrow |
| Safari web extension `finalize` | Web pages only | Too narrow; adds a JS surface |
| `ASCredentialProviderExtensionContext.completeRequest(withTextToInsert:)` | Password fields only | Not applicable |
| `NSExtensionContext.completeRequest(returningItems:)` | Hosts with a completion handler | Effectively nothing |

**Action:** the v1 spec line and the README's "deferred to v1.1" note are corrected as part of this work.

## Scope and non-goals

### In scope

- A `TalkNativeKeyboard` app-extension target (`com.apple.keyboard-service`).
- A `TextReplacement` leaf package: proxy protocol, capture policy, replacement/undo arithmetic, stub proxy.
- A `KeyboardUI` package: panel state machine and keyboard-density views.
- Selection-first capture with a before-cursor fallback.
- Destructive replacement with a one-tap undo.
- Graceful degradation when Full Access is off.

### Out of scope

- Letter keys, autocorrect, emoji plane, dictation, iPad-specific layouts. This is not a typing keyboard.
- Safari web extension.
- Cloud fallback tier (separate spec, `2026-04-18-cloud-fallback-tier-design.md`). The keyboard consumes whatever `LanguageModelProvider` it is given; if the cloud tier ships first, the keyboard inherits it without change.
- Automated end-to-end testing of the installed system keyboard — not possible; see *Testing*.

## Prerequisite spike

**Before any of the below is built**, a throwaway spike must run on a physical device: a bare keyboard extension target that makes a single `FoundationModelsProvider` call and streams one result.

Keyboard extensions run under a tighter memory ceiling than app extensions. Foundation Models executes out-of-process in a system daemon, so model weights should not count against the extension's footprint — but this is an assumption, and the entire feature rests on it. If the extension is jetsammed, the feature is not viable and the spike has cost an afternoon rather than two weeks.

**Exit criterion:** three sequential variant generations complete inside the keyboard on device without termination.

## Architecture

### High-level shape

```
Host app text field
        │  UITextDocumentProxy
        ▼
KeyboardInputViewController        (TalkNativeKeyboard target, UIKit)
  ├── LiveTextDocumentProxy        → adapts UITextDocumentProxy to TextDocumentProxying
  ├── next-keyboard UIButton       → handleInputModeList(from:with:)
  └── UIHostingController
          └── KeyboardPanel        (KeyboardUI package, SwiftUI, UIKit-free)
                └── KeyboardPanelViewModel
                      ├── EnhancementViewModel   (EnhancerUI, unchanged)
                      ├── TextCapture / TextReplacer  (TextReplacement)
                      └── PresetStore            (PresetKit, unchanged)
```

### Package layout

Two new packages, extending the existing DAG:

```
TextReplacement  (leaf, no deps)          — iOS 26 + macOS 26
KeyboardUI       → EnhancerCore, PresetKit, EnhancerUI, TextReplacement
```

`TextReplacement` has no dependencies and no UIKit import, so its tests run under `swift test` on macOS in milliseconds. This is deliberate: it holds the arithmetic that, if wrong, destroys the user's text.

`KeyboardUI` is UIKit-free for the same reason. The mandatory next-keyboard button needs a real `UIButton` and the touch event to pass to `handleInputModeList(from:with:)`, so the view controller owns a bottom bar containing that button and hosts the SwiftUI panel above it. No UIKit crosses into the package.

### `project.yml` changes

New target, embedded in the app alongside `EnhanceExtension`:

```yaml
  TalkNativeKeyboard:
    type: app-extension
    platform: iOS
    deploymentTarget: "26.0"
    sources: [TalkNativeKeyboard]
    info:
      path: TalkNativeKeyboard/Info.plist
      properties:
        CFBundleDisplayName: TalkNative
        NSExtension:
          NSExtensionPointIdentifier: com.apple.keyboard-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).KeyboardInputViewController
          NSExtensionAttributes:
            IsASCIICapable: false
            PrefersRightToLeft: false
            PrimaryLanguage: en-US
            RequestsOpenAccess: true
    entitlements:
      path: TalkNativeKeyboard/TalkNativeKeyboard.entitlements
      properties:
        com.apple.security.application-groups:
          - group.com.axveer.talknative
    dependencies:
      - package: EnhancerCore
      - package: PresetKit
      - package: HistoryKit
      - package: EnhancerUI
      - package: KeyboardUI
      - package: TextReplacement
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.axveer.talknative.keyboard
```

`RequestsOpenAccess: true` makes Full Access *grantable*; it does not make it required. The keyboard loads and functions without it.

Also: two new `packages:` entries, and `- target: TalkNativeKeyboard / embed: true` under the `TalkNative` target's dependencies.

### What does NOT change

`Enhancer`, `LanguageModelProvider` and its conformances, `Preset`, `PresetStore`, `HistoryStore`, `EnhancementViewModel`, `VariantViewState`, `VariantCard`, `ResultSheet`, the app target, and `EnhanceExtension` are all untouched. The keyboard is additive.

## Components

### `TextDocumentProxying` *(TextReplacement)*

```swift
public protocol TextDocumentProxying: AnyObject {
    var selectedText: String? { get }
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}
```

`UITextDocumentProxy` satisfies this shape; `LiveTextDocumentProxy` in the extension target is a thin forwarding wrapper.

### `CapturedText` and `TextCapture` *(TextReplacement)*

```swift
public struct CapturedText: Equatable, Sendable {
    public enum Source: Equatable, Sendable { case selection, contextBefore }
    public let text: String
    public let source: Source
}

public enum CaptureOutcome: Equatable, Sendable {
    case captured(CapturedText)
    case selectionTooLong(count: Int)
    case empty
}

public enum TextCapture {
    public static let defaultMaxChars = 2000

    public static func capture(
        from proxy: any TextDocumentProxying,
        maxChars: Int = defaultMaxChars
    ) -> CaptureOutcome
}
```

Policy, in order:

1. If `selectedText` is non-nil and non-blank after trimming: over `maxChars` → `.selectionTooLong(count:)`; otherwise `.captured` with source `.selection`.
2. Else if `documentContextBeforeInput` is non-nil and non-blank after trimming → `.captured` with source `.contextBefore`, clamped to the **trailing** `maxChars` characters.
3. Else `.empty`.

**An over-long selection is an error, not a clamp.** This asymmetry is required for correctness. A `.selection` plan emits `deleteCount == 1`, which deletes the *entire* selection regardless of how much of it was captured. Clamping a 5000-character selection to its trailing 2000 and replacing would delete all 5000 and insert a rewrite of the last 2000 — silently destroying 3000 characters the user never saw go missing. Clamping is safe only for `.contextBefore`, where `deleteCount` is derived from the clamped string itself.

`maxChars` defaults to 2000, matching `TextEditorBox(maxChars:)` in the app (`EnhanceTab.swift:21`).

### `ReplacementPlan` and `TextReplacer` *(TextReplacement)*

```swift
public struct ReplacementPlan: Equatable, Sendable {
    public let deleteCount: Int
    public let insert: String

    public static func replacing(_ captured: CapturedText, with text: String) -> ReplacementPlan
    public static func undoing(_ plan: ReplacementPlan, restoring captured: CapturedText) -> ReplacementPlan
}

public enum TextReplacer {
    public static func apply(_ plan: ReplacementPlan, to proxy: some TextDocumentProxying)
}
```

`apply` calls `deleteBackward()` exactly `deleteCount` times, then `insertText(plan.insert)`.

**The delete-count rule.** This is the core correctness requirement of the feature:

- `.selection` source → `deleteCount == 1`. A single `deleteBackward()` clears an entire selection atomically.
- `.contextBefore` source → `deleteCount == captured.text.count`, Swift's `Character` count, i.e. **extended grapheme clusters**.

`deleteBackward()` removes one user-perceived character. A regional-indicator flag, a ZWJ family emoji, or a base letter plus a combining accent is one delete each. Using `utf16.count` would over-delete and consume text the user never selected. The undo plan applies the same rule to the inserted string: `deleteCount == plan.insert.count`, `insert == captured.text`.

### `StubTextDocumentProxy` *(TextReplacement)*

An in-memory model of a text field: a full string plus a selection range. `deleteBackward()` clears the selection if one exists, otherwise removes one grapheme cluster before the cursor. `insertText` replaces the selection. Tests assert on **final document state**, not on call sequences — the question that matters is "is the user's text correct afterwards", not "did we call the right methods".

### `KeyboardPanelState` *(KeyboardUI)*

```swift
public enum KeyboardPanelState: Equatable {
    case needsText
    case selectionTooLong(count: Int)
    case ready(CapturedText)
    case enhancing(CapturedText)
    case replaced(undo: ReplacementPlan, original: CapturedText)
    case unavailable(LanguageModelAvailability.Reason)
}
```

### `KeyboardPanelViewModel` *(KeyboardUI)*

`@Observable`, `@MainActor`. Owns the proxy, an `EnhancementViewModel`, and the current state. Public surface:

- `onAppear()` — check availability, capture, auto-start.
- `textDidChange()` / `selectionDidChange()` — forwarded from the view controller.
- `select(variantText:)` — build plan, apply, store inverse, enter `.replaced`.
- `undo()` — apply inverse plan, return to `.ready`.
- `hasFullAccess: Bool` — injected; gates custom presets and history.

### `KeyboardPanel` and `CompactVariantRow` *(KeyboardUI)*

`KeyboardPanel` switches on state. Layout top to bottom: captured-text preview strip, preset chips, three variant rows, and — when Full Access is off and not yet dismissed — a single prompt row. `CompactVariantRow` renders a `VariantViewState` at keyboard density with the `.useThis` action kind already defined in `VariantCard.ActionKind`.

### `KeyboardInputViewController` *(TalkNativeKeyboard target)*

`UIInputViewController` subclass. Pins a fixed ~290pt height constraint on the input view, builds `KeyboardServices`, constructs `LiveTextDocumentProxy`, hosts the panel, and owns the bottom bar with the next-keyboard button. Forwards `textDidChange(_:)` and `selectionDidChange(_:)` to the view model.

### `KeyboardServices` *(TalkNativeKeyboard target)*

Mirrors `ExtensionServices` in `ExtensionHostView.swift`, branching on `hasFullAccess`:

| | Full Access on | Full Access off |
|---|---|---|
| `PresetStore` defaults | App Group suite | `UserDefaults.standard` |
| Presets available | Built-ins + custom | 8 built-ins only |
| `HistoryStore` | App Group container | none; writes skipped |
| Provider | `FoundationModelsProvider` | `FoundationModelsProvider` |

## Data flow

### Cold start

1. User globe-switches to the TalkNative keyboard. `viewDidAppear` fires.
2. Controller pins height, builds `KeyboardServices`, creates the view model.
3. `onAppear()` reads `provider.availability`. If `.unavailable(reason)` → `.unavailable(reason)`, done.
4. `TextCapture.capture(from: proxy, maxChars: 2000)`.
5. `nil` → `.needsText`. Otherwise `.ready(captured)`, then immediately `.enhancing(captured)`.

### Enhancement

6. `EnhancementViewModel.start(inputText: captured.text, activePresets:)` — identical to `ExtensionHostView.begin()`. Three variants stream sequentially, each with a fresh session.
7. Rows fill in live via the existing `VariantViewState` phases.
8. On completion, if Full Access is on, `HistoryStore.insert` is called exactly as the Share extension does.

**Auto-start rationale:** the user deliberately switched to this keyboard. There is no ambiguity of intent, and it matches the Share extension's behaviour of starting on appear.

### Replacement

9. User taps a row. `ReplacementPlan.replacing(captured, with: text)`.
10. `TextReplacer.apply(plan, to: proxy)` — `deleteCount` backspaces, then insert.
11. Store `ReplacementPlan.undoing(plan, restoring: captured)`; enter `.replaced(undo:original:)`.
12. A confirmation strip appears in place of the preview strip: `✓ Replaced · Undo`. The variant rows stay visible but are inert — the user undoes first to pick a different one. This keeps the undo plan's precondition (inserted text immediately behind the cursor) trivially true.

### Undo

13. Tapping Undo applies the inverse plan and returns to `.ready`, with the variants live again so the user can pick a different one.

**The restored capture changes source.** Undo returns to `.ready(CapturedText(text: original.text, source: .contextBefore))` — **not** the original `CapturedText`. After replace-then-undo the restored text sits before the cursor with nothing selected, even if the original capture came from a selection. Carrying `.selection` forward would make the next replacement emit `deleteCount == 1` against a field that has no selection, deleting exactly one character instead of the intended span. The `original` payload on `.replaced` exists to make this transition possible.

### Live re-capture

`textDidChange` and `selectionDidChange` re-run capture, so selecting a sentence after the panel is already open re-targets it. Two guards:

- **Suppressed during `.enhancing`.** Our own `insertText` fires `textDidChange`; without this, replacement would re-trigger capture mid-flight.
- **Any external `textDidChange` while in `.replaced` invalidates the undo plan** and drops to `.ready` with a fresh capture.

The second guard is load-bearing. The undo plan's `deleteCount` assumes the inserted text still sits immediately behind the cursor. If the user typed a word after replacing, a blind undo would delete that word instead. Invalidation is the correct and conservative response.

## Error handling

| Condition | Behaviour |
|---|---|
| `availability == .unavailable(reason)` | `.unavailable` panel rendering `EnhancerError.modelUnavailable(reason).userFacingMessage` — same copy as the app |
| Capture returns `nil` (empty field) | `.needsText`: "Select the text you want to rewrite, or type something first." |
| `documentContext` returns `nil` (Gmail-class hosts) | Indistinguishable from empty → `.needsText`. The copy nudges toward selecting text, which is exact and unaffected |
| Host truncates `documentContextBeforeInput` | Not detectable. Mitigated by showing the captured text — see below |
| Capture exceeds 2000 chars | Clamped to trailing 2000, labelled in the preview strip |
| Per-variant model failure | Already modelled by `VariantViewState.failed`; no new handling |
| Full Access off | Built-ins only, no history, one dismissible prompt row |
| Undo requested after external edit | Undo already invalidated by the re-capture guard; the strip is gone |

### Truncation is shown, not guessed

`documentContextBeforeInput` is reported to truncate at roughly 300 characters in several major hosts, and there is no reliable way to detect that it happened. Rather than silently rewriting a fragment of what the user believes they are rewriting, the panel renders the captured text as a preview strip above the variants. What you see is what gets rewritten. The `.needsText` and empty-state copy both steer toward selecting text, because a selection is exact and immune to this limit.

### The Full Access prompt is instructional, not a link

A keyboard extension has no access to `UIApplication.shared` and cannot reliably open a URL, so the prompt row cannot deep-link into Settings. It shows the literal path as text — "Settings → General → Keyboard → Keyboards → TalkNative → Allow Full Access" — plus a dismiss control. Any responder-chain trick to reach `openURL` from an extension is out of scope and App Store risk.

The dismissal flag is written to the keyboard's own `UserDefaults.standard`, not the App Group — the App Group is unreachable in precisely the state where this prompt is shown.

## Testing

### `TextReplacementTests` (macOS, `swift test`)

Carries the weight of the feature.

**Capture policy**
- Selection wins over context when both are present.
- Whitespace-only selection falls through to context.
- Both empty/blank → `nil`.
- Over-length capture keeps the **trailing** `maxChars` characters.

**Delete arithmetic** — asserted across a Unicode corpus: ASCII, single emoji, ZWJ family sequence, regional-indicator flag, `e` + combining acute, CRLF.
- `.selection` plans always emit `deleteCount == 1`.
- `.contextBefore` plans emit the grapheme-cluster count.
- Each corpus entry is a case where a UTF-16 count would over-delete.

**Round-trip property** — for every corpus entry, replace-then-undo against `StubTextDocumentProxy` leaves the document identical to its starting state. This single property is the feature's primary safety guarantee.

### `KeyboardUITests` (macOS, `swift test`)

State machine driven by `StubLanguageModelProvider` + `StubTextDocumentProxy`:

- `needsText → ready → enhancing → replaced → undo → ready`.
- After undo, the restored state's source is `.contextBefore` even when the original capture was `.selection`; a second replace from that state deletes the full restored span, not one character.
- External `textDidChange` while `.replaced` invalidates undo.
- Re-capture is suppressed during `.enhancing`.
- `hasFullAccess == false` → active presets are exactly the 8 built-ins, no history write attempted.
- `.unavailable` short-circuits before any capture.

### `TalkNativeUITests` addition

XCUITest **cannot** enable or drive a third-party keyboard — that requires a manual toggle in iOS Settings. There is no automated end-to-end test of the installed keyboard, and this spec does not pretend otherwise.

Partial substitute: a `-showKeyboardPanel` launch argument (added to `LaunchArguments.swift`) hosts the real `KeyboardPanel` inside the app over a `StubTextDocumentProxy`, so `TalkNativeUITests` exercises the actual SwiftUI view, its states, and the undo strip.

### Manual device checklist

Required before release; recorded in the plan as an explicit task.

1. Enable the keyboard in Settings → General → Keyboard → Keyboards.
2. Without Full Access: verify built-ins present, no custom presets, prompt row shown and dismissible.
3. Grant Full Access: verify custom presets appear and Recents records entries.
4. Exercise in Messages, Notes, Safari, and Gmail: selection replace, before-cursor replace, undo.
5. Emoji and accented text: replace and undo, confirm no over-deletion.
6. Repeated invocations in one session: confirm no jetsam.
7. Confirm the next-keyboard button switches away correctly.

### CI changes

- `scripts/no-network-check.sh:5` — append `TalkNativeKeyboard` to `TARGETS`. New packages under `Packages/` are already covered by the recursive glob.
- `scripts/lint.sh:10` — append `TalkNativeKeyboard` to the `swift-format lint` argument list.
- `.github/workflows/ci.yml` — add `swift test` steps for `TextReplacement` and `KeyboardUI` alongside the existing four packages.

## Documentation corrections

Part of this work, not a follow-up:

- `docs/superpowers/specs/2026-04-18-talknative-design.md` — lines 29 and 72: correct the in-place-replacement mechanism and point to this spec.
- `README.md:68` — replace the "Action extension deferred to v1.1" note with the keyboard, including the Full Access explanation.
- `CLAUDE.md` — add the keyboard target and two packages to the architecture section.

## Open questions

None. The one material unknown — whether Foundation Models is usable inside a keyboard extension's memory budget — is handled by the prerequisite spike, which gates the rest of the work.
