# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

TalkNative is an on-device iOS text enhancer for non-native English speakers, built on Apple Foundation Models (iOS 26+, Apple Intelligence required). Given input text, it streams three rewrites in parallel tone presets. Swift 6, SwiftUI, Swift Concurrency throughout.

Design specs live in `docs/superpowers/specs/`, implementation plans in `docs/superpowers/plans/`. The cloud-fallback-tier spec/plan (BYOK Anthropic tier for non-Apple-Intelligence devices) is approved but **not yet implemented** — the no-network constraint below still holds.

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

- **EnhancerCore** — `Enhancer` actor, prompts, the `LanguageModelProvider` protocol and its conformances (`FoundationModelsProvider` for production, `StubLanguageModelProvider` for tests). Depends only on FoundationModels.
- **PresetKit** — `Preset` model, 8 built-ins, `PresetStore` (UserDefaults-backed) with custom-preset CRUD. No dependencies.
- **HistoryKit** — `RecentItem` SwiftData `@Model`, `HistoryStore` with a 50-item cap. Depends only on SwiftData.
- **EnhancerUI** — shared SwiftUI components (`ResultSheet`, `VariantCard`, `PresetPicker`, `EnhancementViewModel`). Depends on EnhancerCore + PresetKit.

Key seams to know:

- **`LanguageModelProvider` protocol** (EnhancerCore) is the deliberate abstraction boundary for model backends. The planned cloud tier adds a second conformance here; UI and `Enhancer` stay provider-agnostic.
- **`Enhancer.enhance(_:)`** returns an `AsyncStream<VariantChunk>` (`.started` / `.delta` / `.completed` / `.failed` per preset). Generations run **sequentially** per preset, each with a fresh session — no context carries between generations.
- **`AppServices`** (TalkNative target) is the composition root: `makeProduction()` wires real stores + `FoundationModelsProvider`; `makeStubbed()` wires `StubLanguageModelProvider` for UI tests.
- **App Group** `group.com.axveer.talknative` (see `AppGroup.swift`): `PresetStore` defaults and the SwiftData container both live in the group so the app and the Share extension share state.
- **UI-test hooks** (`LaunchArguments.swift`): launch arg `-useStubEnhancer` swaps in the stub provider; env var `TALKNATIVE_PREFILL_INPUT` prefills the input box.

## Constraints

- **Zero network calls.** Enforced by `scripts/no-network-check.sh` in CI over `Packages`, `TalkNative`, and `EnhanceExtension`. (The cloud-fallback spec will narrow this guard when implemented — until then, do not introduce networking APIs.)
- No accounts, no telemetry; user data never leaves the device.
- The Action extension (in-place text replacement) is deferred to v1.1; only the Share extension ships in v1.
