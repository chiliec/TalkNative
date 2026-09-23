# TalkNative

[![CI](https://github.com/chiliec/TalkNative/actions/workflows/ci.yml/badge.svg)](https://github.com/chiliec/TalkNative/actions/workflows/ci.yml)
[![Device Smoke](https://github.com/chiliec/TalkNative/actions/workflows/device-smoke.yml/badge.svg)](https://github.com/chiliec/TalkNative/actions/workflows/device-smoke.yml)

**Make your English sound native — entirely on your iPhone.**

TalkNative rewrites text for non-native English speakers using Apple Foundation Models (iOS 26+, Apple Intelligence). Every enhancement returns three rewrites in configurable tones — fixing grammar, idioms, and awkward phrasing while preserving your meaning and register.

- 🔒 **Private by design** — zero network calls on Apple-Intelligence devices, no accounts, no telemetry. Only `GatewayProvider.swift` may talk to the network (the cloud fallback tier, used with consent), enforced by the allowlist in `scripts/no-network-check.sh`.
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

### Keyboard extension

In-place rewriting is delivered by a custom keyboard rather than an Action extension — iOS gives an Action extension no way to write back into the host app's text field. Enable it under Settings → General → Keyboard → Keyboards → TalkNative.

The keyboard works immediately with the eight built-in presets. Granting **Allow Full Access** additionally makes your custom presets and Recents available to it; network access is confined to `GatewayProvider.swift`'s cloud fallback tier, enforced in CI by `scripts/no-network-check.sh`.

## Cloud gateway tier

On iOS 26 devices without Apple Intelligence, `GatewayProvider` streams enhancements from a remote gateway after user consent, with the gateway key injected at build time via `Config/Secrets.xcconfig`. All other devices keep running fully on-device.
