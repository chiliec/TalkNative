# TalkNative

On-device iOS text enhancer for non-native English speakers. Uses Apple Foundation Models (iOS 26+).

## Requirements
- macOS with Xcode 16+
- iOS 26 simulator or device with Apple Intelligence support
- `xcodegen` (`brew install xcodegen`)
- `swift-format` (`brew install swift-format`)

## Build
```
xcodegen generate
open TalkNative.xcodeproj
```

## Run tests
```
swift test --package-path Packages/EnhancerCore
swift test --package-path Packages/PresetKit
swift test --package-path Packages/HistoryKit
swift test --package-path Packages/EnhancerUI
```

### Known v1 limitation

The Action extension (in-place text replacement) is deferred to v1.1. The Share extension covers the primary invocation flow. See the spec section "Invocation surfaces" for intent.

Design spec: `docs/superpowers/specs/2026-04-18-talknative-design.md`
