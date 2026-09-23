# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TalkNative is an on-device iOS text enhancer for non-native English speakers, built on Apple Foundation Models (iOS 26+, Apple Intelligence required for on-device generation; devices without it fall back to the cloud gateway tier below). Given input text, it streams three rewrites in parallel tone presets. Swift 6, SwiftUI, Swift Concurrency throughout.

Design specs live in `docs/superpowers/specs/`, implementation plans in `docs/superpowers/plans/`. On iOS 26 devices without Apple Intelligence, `GatewayProvider` streams from the TalkNative gateway (`gateway.nextgensoft.co`, Anthropic format) after user consent; the key is injected from the gitignored `Config/Secrets.xcconfig` (see `Config/Secrets.example.xcconfig`).

## Commands

The Xcode project is **generated** — never edit `TalkNative.xcodeproj` directly; edit `project.yml` and regenerate:

```sh
xcodegen generate
```

Package tests (fast, run on macOS, no simulator needed):

```sh
swift test --package-path Packages/EnhancerCore   # same for PresetKit, HistoryKit, EnhancerUI
swift test --package-path Packages/EnhancerCore --filter SomeTestName   # single test
```

App-level tests require an iOS 26 simulator (CI uses iPhone 17 Pro / OS 26.4):

```sh
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4" \
  -only-testing:TalkNativeTests CODE_SIGNING_ALLOWED=NO    # or TalkNativeUITests
```

Lint and CI guards (both run in CI; lint is `--strict`, config in `.swift-format`):

```sh
./scripts/lint.sh                # swift-format lint over all targets
./scripts/no-network-check.sh    # fails on URLSession/Network/NWConnection usage
```

`DeviceSmokeTests` is a separate scheme run nightly in CI (`device-smoke` workflow); it exercises the real Foundation Models stack.

## Architecture

Four local SPM packages with a strict dependency DAG, consumed by two targets (app + Share extension):

- **EnhancerCore** — `Enhancer` actor, prompts, the `LanguageModelProvider` protocol and its conformances (`FoundationModelsProvider` for production, `GatewayProvider` for the cloud fallback tier, `StubLanguageModelProvider` for tests). Depends only on FoundationModels.
- **PresetKit** — `Preset` model, 8 built-ins, `PresetStore` (UserDefaults-backed) with custom-preset CRUD. No dependencies.
- **HistoryKit** — `RecentItem` SwiftData `@Model`, `HistoryStore` with a 50-item cap. Depends only on SwiftData.
- **EnhancerUI** — shared SwiftUI components (`ResultSheet`, `VariantCard`, `PresetPicker`, `EnhancementViewModel`). Depends on EnhancerCore + PresetKit.
- **TextReplacement** — leaf package holding `TextDocumentProxying`, the selection-first capture policy, and all replace/undo delete-count arithmetic. No dependencies, no UIKit; tests run on macOS. Delete counts are grapheme-cluster counts, never `utf16.count`.
- **KeyboardUI** — `KeyboardPanelState`, `KeyboardPanelViewModel`, and keyboard-density views. Depends on EnhancerCore + PresetKit + EnhancerUI + TextReplacement. Never imports UIKit.

Key seams to know:

- **`LanguageModelProvider` protocol** (EnhancerCore) is the deliberate abstraction boundary for model backends. The cloud gateway tier adds a second conformance here (`GatewayProvider`); UI and `Enhancer` stay provider-agnostic.
- **`Enhancer.enhance(_:)`** returns an `AsyncStream<VariantChunk>` (`.started` / `.delta` / `.completed` / `.failed` per preset). Generations run **sequentially** per preset, each with a fresh session — no context carries between generations.
- **`AppServices`** (TalkNative target) is the composition root: `makeProduction()` wires real stores + routes through `ProviderSelector`, which picks `FoundationModelsProvider` or `GatewayProvider`; `makeStubbed()` wires `StubLanguageModelProvider` for UI tests.
- **App Group** `group.com.axveer.talknative` (see `AppGroup.swift`): `PresetStore` defaults and the SwiftData container both live in the group so the app and the Share extension share state.
- **UI-test hooks** (`LaunchArguments.swift`): launch arg `-useStubEnhancer` swaps in the stub provider; env var `TALKNATIVE_PREFILL_INPUT` prefills the input box; `-simulateIneligibleDevice` (with `-useStubEnhancer`) shows the cloud consent flow.
- **`TalkNativeKeyboard`** — custom keyboard extension (`com.apple.keyboard-service`). Holds only `KeyboardInputViewController`, `LiveTextDocumentProxy`, and `KeyboardServices`. Works without Full Access using built-in presets; Full Access unlocks App Group presets and history.
- **`ProviderSelector`** (EnhancerCore) — the only place that chooses between `FoundationModelsProvider` and `GatewayProvider`; all three composition roots call it.

## Constraints

- **Zero network calls on Apple-Intelligence devices.** Only `GatewayProvider.swift` may use networking APIs, enforced by the allowlist in `scripts/no-network-check.sh`.
- No accounts, no telemetry; user data never leaves the device, except the text sent to the gateway in cloud mode, with consent.
- In-place text replacement ships as a **custom keyboard extension**, not an Action extension. An Action extension cannot write back into a host app's text field on iOS — see `docs/superpowers/specs/2026-08-01-keyboard-extension-design.md`.
