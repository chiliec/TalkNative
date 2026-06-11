# TalkNative

[![CI](https://github.com/chiliec/TalkNative/actions/workflows/ci.yml/badge.svg)](https://github.com/chiliec/TalkNative/actions/workflows/ci.yml)
[![Device Smoke](https://github.com/chiliec/TalkNative/actions/workflows/device-smoke.yml/badge.svg)](https://github.com/chiliec/TalkNative/actions/workflows/device-smoke.yml)

**Make your English sound native — entirely on your iPhone.**

TalkNative rewrites text for non-native English speakers using Apple Foundation Models (iOS 26+, Apple Intelligence). Every enhancement returns three rewrites in configurable tones — fixing grammar, idioms, and awkward phrasing while preserving your meaning and register.

- 🔒 **Private by design** — zero network calls, no accounts, no telemetry. Enforced in CI.
- ⚡ **Streaming results** — three tone variants stream in live, one card per preset.
- 📤 **Works everywhere** — standalone app or via the Share sheet from any app.
- 🕘 **Recent history** — your last 50 enhancements, stored locally.

## Requirements

| Tool | Notes |
|---|---|
| Xcode 16+ | macOS host |
| iOS 26 simulator or device | Device must support Apple Intelligence |
| [`xcodegen`](https://github.com/yonaskolb/XcodeGen) | `brew install xcodegen` |
| [`swift-format`](https://github.com/swiftlang/swift-format) | `brew install swift-format` |

## Getting started

```sh
xcodegen generate
open TalkNative.xcodeproj
```

The `.xcodeproj` is generated — edit `project.yml` and re-run `xcodegen generate` to change targets or settings.

## Testing

Fast package tests (run on macOS, no simulator):

```sh
swift test --package-path Packages/EnhancerCore
swift test --package-path Packages/PresetKit
swift test --package-path Packages/HistoryKit
swift test --package-path Packages/EnhancerUI
```

App, UI, and nightly device-smoke tests run in CI against an iOS 26 simulator — see [`.github/workflows`](.github/workflows).

Lint and the no-network guard:

```sh
./scripts/lint.sh
./scripts/no-network-check.sh
```

## Architecture

Four local Swift packages with a strict dependency DAG, shared by the app and the Share extension via an App Group:

| Package | Role |
|---|---|
| `EnhancerCore` | `Enhancer` actor, prompts, `LanguageModelProvider` seam, Foundation Models wrapper |
| `PresetKit` | Tone presets — 8 built-ins plus custom preset CRUD |
| `HistoryKit` | SwiftData-backed recent history (50-item cap) |
| `EnhancerUI` | Shared SwiftUI components (result sheet, variant cards, preset picker) |

Full design spec: [`docs/superpowers/specs/2026-04-18-talknative-design.md`](docs/superpowers/specs/2026-04-18-talknative-design.md)

## Known v1 limitation

The Action extension (in-place text replacement) is deferred to v1.1. The Share extension covers the primary invocation flow — see the spec section "Invocation surfaces" for intent.

## Roadmap

A BYOK cloud fallback tier (Anthropic Claude Haiku) for devices without Apple Intelligence is specced and approved: [`docs/superpowers/specs/2026-04-18-cloud-fallback-tier-design.md`](docs/superpowers/specs/2026-04-18-cloud-fallback-tier-design.md)
