# TalkNative — Design Spec

**Date:** 2026-04-18
**Status:** Approved for implementation planning

## Summary

TalkNative is an iOS app that makes text sound more native for non-native English speakers. All enhancement happens on-device using Apple's Foundation Models framework — no network, no cloud, no accounts. Users invoke it three ways: as a standalone app, as a Share extension, and as an Action extension. Each enhancement returns three rewrites in parallel user-configurable tones.

## Target users

Non-native English speakers writing in both professional contexts (email, Slack, LinkedIn) and casual contexts (iMessage, social, dating). The app preserves the user's intended register rather than normalizing everything to formal.

## Core feature

Given a string of English text, produce three alternative rewrites — one per active tone preset. Each rewrite fixes grammar, idioms, article usage, and awkward phrasing while preserving the original meaning and, by default, the original register.

## Constraints and guarantees

- **On-device only.** Zero network calls anywhere in the app. Enforced by CI grep test that fails if any package imports `URLSession`, `Network`, or `NWConnection`.
- **Apple Intelligence required.** Minimum iOS 26; device must support Apple Intelligence (iPhone 15 Pro/Pro Max, all iPhone 16+, iPad M1+).
- **No accounts, no sync, no telemetry.** User data never leaves the device.
- **Privacy statement** rendered in Settings → Privacy.

## Invocation surfaces

1. **Standalone app.** Home tab with a textbox, preset chips, and an Enhance button. Opens the Result sheet.
2. **Share extension** (`EnhanceExtension` target, Share activation rule). User selects text in any app, taps Share → TalkNative. Result sheet shows variants; Copy is the terminal action.
3. **Action extension** (same target, Action activation rule). User selects text, taps "…" in the text menu → TalkNative. Result sheet shows variants; tapping one replaces the selected text in place via `NSExtensionContext.completeRequest`.

## Architecture

Multi-package Swift architecture with a strict dependency DAG.

```
Packages/
├── EnhancerCore      — Foundation Models wrapper, Enhancer actor, streaming
│                       Dependencies: FoundationModels only
│
├── PresetKit         — Preset model, 8 built-ins, PresetStore, custom CRUD
│                       Dependencies: none
│
├── HistoryKit        — RecentItem @Model, HistoryStore (SwiftData), 50-item cap
│                       Dependencies: SwiftData only
│
└── EnhancerUI        — Shared SwiftUI components (VariantCard, PresetPicker, ResultSheet)
                        Dependencies: EnhancerCore, PresetKit

Targets/
├── TalkNative (iOS app)
│       Deps: EnhancerCore, PresetKit, HistoryKit, EnhancerUI
│
└── EnhanceExtension (Share + Action)
        Deps: EnhancerCore, PresetKit, HistoryKit, EnhancerUI
```

**App Group:** `group.com.<developerid>.talknative`. Both targets are entitled; the preset store and the SwiftData container both use the App Group URL so the extension and main app read/write the same data.

## Enhancement lifecycle

When the user taps "Enhance":

1. **Validate input.** Empty / whitespace-only disables the button. Over 2000 characters shows an inline warning; input is not silently truncated.
2. **Check availability.** Read `SystemLanguageModel.default.availability`:
   - `.available` → proceed.
   - `.unavailable(.deviceNotEligible)` → full-screen "device not supported" view; app stays installed so Recent history is readable.
   - `.unavailable(.appleIntelligenceNotEnabled)` → "Turn on Apple Intelligence" with deep link to Settings.
   - `.unavailable(.modelNotReady)` → "Downloading — come back in a few minutes." Auto-retry on foreground.
3. **Open the Result sheet** with three placeholder cards, one per active preset. Cards 2 and 3 show "Waiting…" until their turn starts.
4. **Sequential streaming.** The `Enhancer` actor runs three streaming generations, one per active preset, in order. Each generation uses a fresh `LanguageModelSession` (no context accumulation between enhancements). As tokens arrive, they fill the corresponding card's text.
5. **Completion.** Each card becomes actionable (Copy, Regenerate). When all three finish, `HistoryStore` records a `RecentItem` with input, the three outputs, preset IDs, and a label snapshot per preset.
6. **User action.** Copy sets `UIPasteboard.general.string`. In the Action extension, tapping a variant calls `completeRequest(returningItems:)` for in-place replacement.

### Prompt shape (`EnhancerCore/Prompts.swift`)

System instructions (same for every generation):
```
You rewrite the user's message so it sounds like a native English speaker wrote it.
Fix grammar, idioms, article usage, and awkward phrasing.
Preserve the user's meaning and intent exactly.
Preserve register (casual stays casual, formal stays formal) unless the style instruction says otherwise.
Apply the style: {preset.instructions}
Output only the rewritten message. No preamble, no explanations.
```

User prompt: `Original: {userInput}`

### Model abstraction

`EnhancerCore` exposes a `LanguageModelProvider` protocol. Production uses `FoundationModelsProvider` wrapping `LanguageModelSession`. Tests use `StubLanguageModelProvider` that returns scripted `AsyncThrowingStream<String, Error>` chunks. This is the seam for deterministic testing.

## Data model

### Presets (UserDefaults, key `presets.v1` in the App Group suite)

```swift
struct Preset: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var instructions: String
    var isBuiltIn: Bool
    var sortOrder: Int
}

struct PresetSelection: Codable {
    var activePresetIDs: [UUID]   // exactly 3; validated on write
}
```

**Eight built-in presets** (seeded on first launch): Casual, Neutral, Formal, Friendly, Direct, Professional, Warm, Confident. Each has hand-tuned `instructions` prompt text. Built-in presets cannot be deleted but can be toggled in/out of the active 3.

**Custom presets.** User can create up to 20 custom presets (hard cap; the New Preset button disables at the limit). Each custom preset is `{label, instructions}` plus metadata. Custom presets are fully deletable. Label max 24 chars, instructions max 400 chars — enforced in the editor.

**Default active set on first launch:** Casual, Professional, Warm.

### History (SwiftData, container in App Group URL)

```swift
@Model
final class RecentItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var inputText: String
    var variants: [SavedVariant]
    var deviceModelName: String
}

struct SavedVariant: Codable {
    let presetID: UUID
    let presetLabelSnapshot: String
    let outputText: String
}
```

**Retention:** rolling cap of 50 items. On insert past the cap, oldest is deleted in the same transaction.

**`presetLabelSnapshot`** is stored per variant so that even after the user deletes or renames a preset, old history items still display with their original label.

## UI

Main app uses a flat `TabView` with three tabs:

- **Enhance** (home). Textbox, active-preset chips, Enhance button. Tapping Enhance presents the Result sheet.
- **Recent.** List of `RecentItem`s most-recent-first. Tap to reopen the Result sheet in "saved" mode (shows the stored variants without regenerating). Swipe-to-delete.
- **Settings.** Active-preset picker (pick 3 from built-ins + custom). Custom-preset CRUD. Clear history. About. Privacy.

**Result sheet** is a single SwiftUI view in `EnhancerUI`, used by all three invocation surfaces. Top: original input (read-only). Below: three `VariantCard`s stacked vertically. Each card has a preset label, a body (streamed text or "Generating…" / "Waiting…" placeholder), and Copy + Regenerate buttons. Action-extension mode swaps Copy for "Use this."

**No `NavigationStack` nesting.** The app is flat: sheets for result, pushes inside Settings for preset editing.

## Error handling

| Condition | UI response |
|---|---|
| Device not eligible | Full-screen explainer, list of supported devices, Recent stays read-only |
| Apple Intelligence not enabled | Banner + deep link to Settings |
| Model not ready (downloading) | "Come back in a few minutes," auto-retry on foreground |
| Empty / whitespace input | Enhance button disabled |
| Over 2000 chars | Inline warning; no silent truncation |
| Non-text input via Share | "TalkNative works with text only." |
| `guardrailViolation` mid-generation | That variant card shows "Couldn't enhance this — try rephrasing." Other variants continue |
| `rateLimited` | "Too many requests — try again in a moment." |
| `exceededContextWindow` | "Text is too complex — try splitting it." |
| Unknown error | Generic "Something went wrong," log to `OSLog` category `Enhancer` |
| Sheet dismissed mid-generation | `Task.cancel()` propagates; session released |
| Single-variant Regenerate | Cancel only that sub-task; replace that card; other two unaffected |
| Background mid-generation | Let complete inside iOS background window; if suspended, partial variants show with Regenerate on return |
| Low memory (extension) | Cancel in-flight; show "Memory pressure — try the main app." |

## Out of scope for v1

- Keyboard extension (memory-constrained to 48-60MB, below LLM requirements)
- iCloud sync
- Multi-language (non-English input or non-English target)
- Analytics / telemetry of any kind
- Offline queue / retry
- Per-change "accept/reject" suggestions (Grammarly-style)
- Learning user preferences (auto-picking most-used preset per context)

## Testing strategy

Test target per package:

- `EnhancerCoreTests` — prompt assembly, streaming state machine, cancellation, error mapping, guardrail handling. Uses `StubLanguageModelProvider`.
- `PresetKitTests` — built-in seeding, UserDefaults round-trip, custom CRUD, active-selection invariants.
- `HistoryKitTests` — insert, 50-cap eviction, read-most-recent, clear, any schema migrations.
- `EnhancerUITests` — view-model state transitions, cancellation on dismiss, snapshot tests of `VariantCard` in each state (idle, streaming, complete, error).

**Target:** ~40–60 tests, each <50ms, full suite under 10s.

**Integration tests** (main-app target):

- Full flow with mock `Enhancer` — input → sheet → 3 variants → Copy.
- Entitlements verified; App Group read/write from both targets.
- `XCUITest` smoke: tap Enhance → 3 cards fill → Copy first card → assert pasteboard.

**On-device model smoke tests** (separate `DeviceSmokeTests` scheme, nightly CI on real device or simulator that supports Apple Intelligence):

- 5 representative inputs (casual, formal, typos, idiom, short edge case) against the real `FoundationModelsProvider`.
- Property assertions only: non-empty, differs from input, no refusal phrases. Not exact-string matches.
- Flake tolerance: ~1 in 20 runs, treated as early warning rather than gate.

**Lint / CI rules:**

- `swift-format` in lint mode on every PR.
- No-network grep: fails PR if any package imports `URLSession`, `Network`, `Combine.URLSession`, or `NWConnection`.
- Build all targets + run all package tests on every PR.

**Manual QA checklist** lives in `docs/qa-checklist.md`:

- Fresh install on iPhone 16 Pro — all flows
- Install on iPhone 14 (not Apple Intelligence-capable) — unsupported-device view appears
- Install on iPad Air M1 — iPad layout
- Share from Notes, Mail, Messages where supported
- Action from Safari selected text
- Fly offline — app works normally

## Implementation sequencing hints

(For the writing-plans skill to expand into a plan.)

1. Scaffold Xcode project + 4 Swift packages + 2 targets + App Group entitlement.
2. Build `EnhancerCore` against `StubLanguageModelProvider` first — prompt assembly, streaming, cancellation — with unit tests.
3. Build `PresetKit` with the 8 built-ins + CRUD, fully unit-tested.
4. Build `HistoryKit` with SwiftData model + retention logic, unit-tested.
5. Build `EnhancerUI` components against the stub provider.
6. Wire `FoundationModelsProvider` and run `DeviceSmokeTests` on a real Apple Intelligence device.
7. Main-app screens (Enhance, Recent, Settings).
8. `EnhanceExtension` (Share activation) reusing `ResultSheet`.
9. Action activation configured on the same extension.
10. Unsupported-device + error states.
11. QA pass against the manual checklist.
