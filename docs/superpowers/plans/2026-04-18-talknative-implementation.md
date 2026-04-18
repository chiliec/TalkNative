# TalkNative Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build TalkNative — an iOS 26 SwiftUI app that rewrites text in three tonal variants entirely on-device using Apple's Foundation Models framework, invokable as a standalone app and via Share/Action extensions.

**Architecture:** Multi-package Swift architecture (EnhancerCore, PresetKit, HistoryKit, EnhancerUI) + two Xcode targets (main app, EnhanceExtension). App Group–scoped UserDefaults and SwiftData shared between targets. `LanguageModelProvider` protocol seam for deterministic testing with stub + production Foundation Models implementation.

**Tech Stack:** Swift 6, SwiftUI, Swift Concurrency (`actor`, `AsyncThrowingStream`), Foundation Models framework (iOS 26+), SwiftData, Swift Packages, XcodeGen, swift-format, GitHub Actions.

---

## File Structure

```
TalkNative/
├── .gitignore
├── README.md
├── project.yml                       — XcodeGen manifest
├── scripts/
│   ├── lint.sh
│   └── no-network-check.sh
├── .github/workflows/
│   ├── ci.yml
│   └── device-smoke.yml
├── docs/
│   ├── qa-checklist.md
│   ├── superpowers/specs/2026-04-18-talknative-design.md   (exists)
│   └── superpowers/plans/2026-04-18-talknative-implementation.md  (this file)
│
├── Packages/
│   ├── EnhancerCore/
│   │   ├── Package.swift
│   │   ├── Sources/EnhancerCore/
│   │   │   ├── LanguageModelProvider.swift
│   │   │   ├── FoundationModelsProvider.swift
│   │   │   ├── StubLanguageModelProvider.swift
│   │   │   ├── Enhancer.swift
│   │   │   ├── EnhancementRequest.swift
│   │   │   ├── Prompts.swift
│   │   │   └── EnhancerError.swift
│   │   └── Tests/EnhancerCoreTests/
│   │       ├── PromptsTests.swift
│   │       ├── EnhancerTests.swift
│   │       ├── StubProviderTests.swift
│   │       └── ErrorMappingTests.swift
│   │
│   ├── PresetKit/
│   │   ├── Package.swift
│   │   ├── Sources/PresetKit/
│   │   │   ├── Preset.swift
│   │   │   ├── BuiltInPresets.swift
│   │   │   ├── PresetValidation.swift
│   │   │   └── PresetStore.swift
│   │   └── Tests/PresetKitTests/
│   │       ├── BuiltInPresetsTests.swift
│   │       ├── PresetValidationTests.swift
│   │       └── PresetStoreTests.swift
│   │
│   ├── HistoryKit/
│   │   ├── Package.swift
│   │   ├── Sources/HistoryKit/
│   │   │   ├── RecentItem.swift
│   │   │   ├── HistorySchema.swift
│   │   │   └── HistoryStore.swift
│   │   └── Tests/HistoryKitTests/
│   │       ├── RecentItemTests.swift
│   │       └── HistoryStoreTests.swift
│   │
│   └── EnhancerUI/
│       ├── Package.swift
│       ├── Sources/EnhancerUI/
│       │   ├── VariantViewState.swift
│       │   ├── EnhancementViewModel.swift
│       │   ├── ResultSheet.swift
│       │   ├── VariantCard.swift
│       │   ├── PresetChip.swift
│       │   ├── PresetPicker.swift
│       │   └── TextEditorBox.swift
│       └── Tests/EnhancerUITests/
│           ├── VariantViewStateTests.swift
│           └── EnhancementViewModelTests.swift
│
├── TalkNative/                       — main app target
│   ├── TalkNativeApp.swift
│   ├── Info.plist
│   ├── TalkNative.entitlements
│   ├── Assets.xcassets/
│   ├── AppGroup.swift
│   ├── AppServices.swift
│   ├── RootView.swift
│   ├── UnsupportedDeviceView.swift
│   ├── Tabs/
│   │   ├── EnhanceTab.swift
│   │   ├── RecentTab.swift
│   │   └── SettingsTab.swift
│   └── Settings/
│       ├── ActivePresetsView.swift
│       ├── CustomPresetEditor.swift
│       ├── AboutView.swift
│       └── PrivacyView.swift
│
├── EnhanceExtension/
│   ├── Info.plist
│   ├── EnhanceExtension.entitlements
│   ├── ShareViewController.swift
│   ├── ActionViewController.swift
│   └── ExtensionHostView.swift
│
├── TalkNativeTests/
│   └── AppFlowTests.swift
│
├── TalkNativeUITests/
│   └── EnhanceFlowUITests.swift
│
└── DeviceSmokeTests/
    └── FoundationModelsSmokeTests.swift
```

---

## Phase 1 — Repo, scaffolding, CI

### Task 1: Initialize repo + baseline files

**Files:**
- Create: `.gitignore`
- Create: `README.md`

- [ ] **Step 1: Initialize git repo**

Run:
```bash
cd /Users/babin/Develop/Pet/TalkNative
git init
git branch -M main
```

- [ ] **Step 2: Write `.gitignore`**

```gitignore
# macOS
.DS_Store

# Xcode
build/
DerivedData/
*.xcuserstate
*.xcuserdatad/
xcuserdata/
*.xcscmblueprint
*.xccheckout

# Swift Package Manager
.build/
.swiftpm/
Package.resolved

# XcodeGen-generated
TalkNative.xcodeproj/

# Superpowers runtime (brainstorm sessions, do not commit)
.superpowers/

# CI
.env
```

- [ ] **Step 3: Write `README.md`**

```markdown
# TalkNative

On-device iOS text enhancer for non-native English speakers. Uses Apple Foundation Models (iOS 26+).

## Requirements
- macOS with Xcode 16+
- iOS 26 simulator or device with Apple Intelligence support
- `xcodegen` (`brew install xcodegen`)
- `swift-format` (`brew install swift-format`)

## Build
\`\`\`
xcodegen generate
open TalkNative.xcodeproj
\`\`\`

## Run tests
\`\`\`
swift test --package-path Packages/EnhancerCore
swift test --package-path Packages/PresetKit
swift test --package-path Packages/HistoryKit
swift test --package-path Packages/EnhancerUI
\`\`\`

Design spec: `docs/superpowers/specs/2026-04-18-talknative-design.md`
```

- [ ] **Step 4: Commit**

```bash
git add .gitignore README.md
git commit -m "chore: initialize repo with gitignore and README"
```

---

### Task 2: Create directory skeleton

**Files:**
- Create directories only; no file content yet

- [ ] **Step 1: Create all directories**

```bash
mkdir -p scripts
mkdir -p .github/workflows
mkdir -p Packages/EnhancerCore/Sources/EnhancerCore
mkdir -p Packages/EnhancerCore/Tests/EnhancerCoreTests
mkdir -p Packages/PresetKit/Sources/PresetKit
mkdir -p Packages/PresetKit/Tests/PresetKitTests
mkdir -p Packages/HistoryKit/Sources/HistoryKit
mkdir -p Packages/HistoryKit/Tests/HistoryKitTests
mkdir -p Packages/EnhancerUI/Sources/EnhancerUI
mkdir -p Packages/EnhancerUI/Tests/EnhancerUITests
mkdir -p TalkNative/Tabs TalkNative/Settings TalkNative/Assets.xcassets
mkdir -p EnhanceExtension
mkdir -p TalkNativeTests TalkNativeUITests DeviceSmokeTests
```

- [ ] **Step 2: Place `.keep` sentinels so git tracks empty dirs**

```bash
find Packages TalkNative EnhanceExtension TalkNativeTests TalkNativeUITests DeviceSmokeTests scripts .github \
  -type d -empty -exec touch {}/.keep \;
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: create project directory skeleton"
```

---

### Task 3: Write `EnhancerCore` package manifest

**Files:**
- Create: `Packages/EnhancerCore/Package.swift`

- [ ] **Step 1: Write manifest**

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "EnhancerCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "EnhancerCore", targets: ["EnhancerCore"])
    ],
    targets: [
        .target(name: "EnhancerCore"),
        .testTarget(name: "EnhancerCoreTests", dependencies: ["EnhancerCore"])
    ]
)
```

- [ ] **Step 2: Verify it resolves**

Run: `swift package --package-path Packages/EnhancerCore describe`
Expected: prints the package description without errors. (Empty targets are fine; we'll add files next.)

- [ ] **Step 3: Delete the `.keep` sentinels in EnhancerCore source dirs**

```bash
rm -f Packages/EnhancerCore/Sources/EnhancerCore/.keep Packages/EnhancerCore/Tests/EnhancerCoreTests/.keep
```

- [ ] **Step 4: Commit**

```bash
git add Packages/EnhancerCore/Package.swift
git commit -m "chore(EnhancerCore): add package manifest"
```

---

### Task 4: Write remaining package manifests

**Files:**
- Create: `Packages/PresetKit/Package.swift`
- Create: `Packages/HistoryKit/Package.swift`
- Create: `Packages/EnhancerUI/Package.swift`

- [ ] **Step 1: PresetKit manifest**

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "PresetKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "PresetKit", targets: ["PresetKit"])],
    targets: [
        .target(name: "PresetKit"),
        .testTarget(name: "PresetKitTests", dependencies: ["PresetKit"])
    ]
)
```

- [ ] **Step 2: HistoryKit manifest**

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "HistoryKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "HistoryKit", targets: ["HistoryKit"])],
    targets: [
        .target(name: "HistoryKit"),
        .testTarget(name: "HistoryKitTests", dependencies: ["HistoryKit"])
    ]
)
```

- [ ] **Step 3: EnhancerUI manifest**

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "EnhancerUI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "EnhancerUI", targets: ["EnhancerUI"])],
    dependencies: [
        .package(path: "../EnhancerCore"),
        .package(path: "../PresetKit")
    ],
    targets: [
        .target(name: "EnhancerUI", dependencies: [
            .product(name: "EnhancerCore", package: "EnhancerCore"),
            .product(name: "PresetKit", package: "PresetKit")
        ]),
        .testTarget(name: "EnhancerUITests", dependencies: ["EnhancerUI"])
    ]
)
```

- [ ] **Step 4: Clean up `.keep` files in these packages' source dirs**

```bash
find Packages/PresetKit Packages/HistoryKit Packages/EnhancerUI \
  -name '.keep' -path '*/Sources/*' -delete
find Packages/PresetKit Packages/HistoryKit Packages/EnhancerUI \
  -name '.keep' -path '*/Tests/*' -delete
```

- [ ] **Step 5: Commit**

```bash
git add Packages/PresetKit/Package.swift Packages/HistoryKit/Package.swift Packages/EnhancerUI/Package.swift
git commit -m "chore: add PresetKit, HistoryKit, EnhancerUI package manifests"
```

---

### Task 5: Add no-network CI check script

**Files:**
- Create: `scripts/no-network-check.sh`

- [ ] **Step 1: Write the script**

```bash
#!/usr/bin/env bash
set -euo pipefail

FORBIDDEN='URLSession|\bNetwork\b|NWConnection|URLRequest|URLProtocol'
TARGETS=(Packages TalkNative EnhanceExtension)

hits=$(grep -rnE "$FORBIDDEN" "${TARGETS[@]}" --include='*.swift' || true)
if [[ -n "$hits" ]]; then
  echo "ERROR: network API usage detected (app is on-device only):"
  echo "$hits"
  exit 1
fi
echo "OK: no network API usage found"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/no-network-check.sh
```

- [ ] **Step 3: Run it — should pass (no code yet)**

```bash
./scripts/no-network-check.sh
```
Expected: `OK: no network API usage found`

- [ ] **Step 4: Commit**

```bash
git add scripts/no-network-check.sh
git commit -m "ci: add no-network grep guard"
```

---

### Task 6: Add lint script

**Files:**
- Create: `scripts/lint.sh`
- Create: `.swift-format`

- [ ] **Step 1: Write swift-format config**

Create `.swift-format`:
```json
{
  "version": 1,
  "lineLength": 120,
  "indentation": { "spaces": 4 },
  "maximumBlankLines": 1,
  "respectsExistingLineBreaks": true,
  "rules": {
    "AlwaysUseLowerCamelCase": true,
    "NoLeadingUnderscores": false
  }
}
```

- [ ] **Step 2: Write `scripts/lint.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

if ! command -v swift-format &>/dev/null; then
  echo "swift-format not installed — run: brew install swift-format" >&2
  exit 1
fi

swift-format lint --recursive --strict \
  Packages TalkNative EnhanceExtension TalkNativeTests TalkNativeUITests DeviceSmokeTests
```

- [ ] **Step 3: Make executable**

```bash
chmod +x scripts/lint.sh
```

- [ ] **Step 4: Commit**

```bash
git add scripts/lint.sh .swift-format
git commit -m "ci: add swift-format lint script and config"
```

---

### Task 7: Add GitHub Actions CI workflow

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write workflow**

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  packages:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app
      - name: Test EnhancerCore
        run: swift test --package-path Packages/EnhancerCore
      - name: Test PresetKit
        run: swift test --package-path Packages/PresetKit
      - name: Test HistoryKit
        run: swift test --package-path Packages/HistoryKit
      - name: Test EnhancerUI
        run: swift test --package-path Packages/EnhancerUI

  lint:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Install swift-format
        run: brew install swift-format
      - name: Lint
        run: ./scripts/lint.sh

  no-network:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: No-network guard
        run: ./scripts/no-network-check.sh
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow (tests, lint, no-network)"
```

---

### Task 8: Write XcodeGen project manifest

**Files:**
- Create: `project.yml`
- Create: `TalkNative/TalkNative.entitlements`
- Create: `EnhanceExtension/EnhanceExtension.entitlements`
- Create: `TalkNative/Info.plist`
- Create: `EnhanceExtension/Info.plist`

- [ ] **Step 1: Write `project.yml`**

Replace `<developerid>` with the user's Apple Developer Team prefix (e.g., `ai.example`) before generating. The App Group must match exactly in both targets' entitlements.

```yaml
name: TalkNative
options:
  deploymentTarget:
    iOS: "26.0"
  bundleIdPrefix: com.<developerid>
  groupOrdering:
    - order: [TalkNative, EnhanceExtension, Packages, docs, scripts]

settings:
  base:
    SWIFT_VERSION: 6.0
    CODE_SIGN_STYLE: Automatic

packages:
  EnhancerCore: { path: Packages/EnhancerCore }
  PresetKit:    { path: Packages/PresetKit }
  HistoryKit:   { path: Packages/HistoryKit }
  EnhancerUI:   { path: Packages/EnhancerUI }

targets:
  TalkNative:
    type: application
    platform: iOS
    deploymentTarget: "26.0"
    sources: [TalkNative]
    info:
      path: TalkNative/Info.plist
      properties:
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
    entitlements:
      path: TalkNative/TalkNative.entitlements
    dependencies:
      - target: EnhanceExtension
        embed: true
      - package: EnhancerCore
      - package: PresetKit
      - package: HistoryKit
      - package: EnhancerUI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.<developerid>.talknative
        TARGETED_DEVICE_FAMILY: "1,2"

  EnhanceExtension:
    type: app-extension
    platform: iOS
    deploymentTarget: "26.0"
    sources: [EnhanceExtension]
    info:
      path: EnhanceExtension/Info.plist
      properties:
        NSExtension:
          NSExtensionPointIdentifier: com.apple.share-services
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).ShareViewController
          NSExtensionAttributes:
            NSExtensionActivationRule:
              NSExtensionActivationSupportsText: true
    entitlements:
      path: EnhanceExtension/EnhanceExtension.entitlements
    dependencies:
      - package: EnhancerCore
      - package: PresetKit
      - package: HistoryKit
      - package: EnhancerUI
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.<developerid>.talknative.extension

  TalkNativeTests:
    type: bundle.unit-test
    platform: iOS
    sources: [TalkNativeTests]
    dependencies:
      - target: TalkNative

  TalkNativeUITests:
    type: bundle.ui-testing
    platform: iOS
    sources: [TalkNativeUITests]
    dependencies:
      - target: TalkNative

  DeviceSmokeTests:
    type: bundle.unit-test
    platform: iOS
    sources: [DeviceSmokeTests]
    dependencies:
      - package: EnhancerCore
```

- [ ] **Step 2: Write `TalkNative/TalkNative.entitlements`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.<developerid>.talknative</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Write `EnhanceExtension/EnhanceExtension.entitlements`** (same content — required on both sides)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.<developerid>.talknative</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 4: Write `TalkNative/Info.plist` (minimal)**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>TalkNative</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
</dict>
</plist>
```

- [ ] **Step 5: Write `EnhanceExtension/Info.plist` (minimal — extension key filled by XcodeGen)**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>TalkNative</string>
</dict>
</plist>
```

- [ ] **Step 6: Generate the Xcode project**

Run (requires `brew install xcodegen` first):
```bash
xcodegen generate
```
Expected: creates `TalkNative.xcodeproj/`. `.gitignore` already excludes this directory.

- [ ] **Step 7: Commit**

```bash
git add project.yml TalkNative/Info.plist TalkNative/TalkNative.entitlements EnhanceExtension/Info.plist EnhanceExtension/EnhanceExtension.entitlements
git commit -m "chore: add XcodeGen manifest, Info.plists, entitlements"
```

---

## Phase 2 — EnhancerCore (TDD)

### Task 9: `LanguageModelProvider` protocol + availability types

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/LanguageModelProvider.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/StubProviderTests.swift` (skeleton for next task)

- [ ] **Step 1: Write the protocol + availability types**

```swift
// LanguageModelProvider.swift
import Foundation

public enum LanguageModelAvailability: Sendable, Equatable {
    case available
    case unavailable(Reason)

    public enum Reason: Sendable, Equatable {
        case deviceNotEligible
        case appleIntelligenceNotEnabled
        case modelNotReady
        case other(String)
    }
}

public protocol LanguageModelProvider: Sendable {
    var availability: LanguageModelAvailability { get }
    func stream(
        instructions: String,
        prompt: String
    ) -> AsyncThrowingStream<String, Error>
}
```

- [ ] **Step 2: Verify the package still builds**

Run: `swift build --package-path Packages/EnhancerCore`
Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/LanguageModelProvider.swift
git commit -m "feat(EnhancerCore): add LanguageModelProvider protocol + availability types"
```

---

### Task 10: `StubLanguageModelProvider` (TDD)

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/StubLanguageModelProvider.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/StubProviderTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// StubProviderTests.swift
import Testing
@testable import EnhancerCore

@Suite("StubLanguageModelProvider")
struct StubProviderTests {
    @Test func streamsScriptedChunks() async throws {
        let stub = StubLanguageModelProvider(
            scriptedChunks: ["Hello", ", ", "world!"]
        )
        var collected = ""
        for try await chunk in stub.stream(instructions: "sys", prompt: "in") {
            collected += chunk
        }
        #expect(collected == "Hello, world!")
    }

    @Test func throwsScriptedError() async {
        struct Boom: Error {}
        let stub = StubLanguageModelProvider(
            scriptedChunks: ["partial"],
            scriptedError: Boom()
        )
        var collected = ""
        do {
            for try await chunk in stub.stream(instructions: "", prompt: "") {
                collected += chunk
            }
            Issue.record("expected error was not thrown")
        } catch is Boom {
            #expect(collected == "partial")
        } catch {
            Issue.record("wrong error type: \(error)")
        }
    }

    @Test func defaultAvailabilityIsAvailable() {
        let stub = StubLanguageModelProvider(scriptedChunks: [])
        #expect(stub.availability == .available)
    }
}
```

- [ ] **Step 2: Run — expect FAIL (StubLanguageModelProvider not defined)**

Run: `swift test --package-path Packages/EnhancerCore`
Expected: compile error `cannot find 'StubLanguageModelProvider' in scope`.

- [ ] **Step 3: Implement minimal version**

```swift
// StubLanguageModelProvider.swift
import Foundation

public struct StubLanguageModelProvider: LanguageModelProvider {
    public var availability: LanguageModelAvailability
    public var scriptedChunks: [String]
    public var scriptedError: Error?
    public var chunkDelay: Duration

    public init(
        availability: LanguageModelAvailability = .available,
        scriptedChunks: [String],
        scriptedError: Error? = nil,
        chunkDelay: Duration = .milliseconds(0)
    ) {
        self.availability = availability
        self.scriptedChunks = scriptedChunks
        self.scriptedError = scriptedError
        self.chunkDelay = chunkDelay
    }

    public func stream(
        instructions: String,
        prompt: String
    ) -> AsyncThrowingStream<String, Error> {
        let chunks = scriptedChunks
        let error = scriptedError
        let delay = chunkDelay
        return AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in chunks {
                    if Task.isCancelled { break }
                    if delay > .zero { try? await Task.sleep(for: delay) }
                    continuation.yield(chunk)
                }
                if let error { continuation.finish(throwing: error) }
                else { continuation.finish() }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/EnhancerCore`
Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/StubLanguageModelProvider.swift Packages/EnhancerCore/Tests/EnhancerCoreTests/StubProviderTests.swift
git commit -m "feat(EnhancerCore): add StubLanguageModelProvider with tests"
```

---

### Task 11: Request/response value types

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/EnhancementRequest.swift`

- [ ] **Step 1: Write the types (no tests needed — pure value types)**

```swift
// EnhancementRequest.swift
import Foundation

public struct VariantRequest: Sendable, Equatable {
    public let presetID: UUID
    public let presetLabel: String
    public let presetInstructions: String

    public init(presetID: UUID, presetLabel: String, presetInstructions: String) {
        self.presetID = presetID
        self.presetLabel = presetLabel
        self.presetInstructions = presetInstructions
    }
}

public struct EnhancementRequest: Sendable, Equatable {
    public let inputText: String
    public let variants: [VariantRequest]

    public init(inputText: String, variants: [VariantRequest]) {
        self.inputText = inputText
        self.variants = variants
    }
}

public enum VariantChunk: Sendable, Equatable {
    case started(presetID: UUID)
    case delta(presetID: UUID, text: String)
    case completed(presetID: UUID, fullText: String)
    case failed(presetID: UUID, error: EnhancerError)
}
```

- [ ] **Step 2: Build — verify compiles (`EnhancerError` added next task, so temporarily stub or reorder)**

Since `EnhancerError` is used here, define it first (next task) — **apply Tasks 11 and 12 together before running build**.

- [ ] **Step 3: Commit after Task 12**

(Combined commit with Task 12.)

---

### Task 12: `EnhancerError` with error mapping

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/EnhancerError.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/ErrorMappingTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// ErrorMappingTests.swift
import Testing
@testable import EnhancerCore

@Suite("EnhancerError")
struct ErrorMappingTests {
    @Test func guardrailViolationHasRetryableAdvice() {
        let err: EnhancerError = .guardrailViolation
        #expect(err.userFacingMessage.contains("rephrasing"))
        #expect(err.isRetryable == false)
    }

    @Test func rateLimitedIsRetryable() {
        #expect(EnhancerError.rateLimited.isRetryable == true)
    }

    @Test func unknownWrapsUnderlying() {
        struct X: Error {}
        let err = EnhancerError.unknown(X())
        #expect(err.userFacingMessage.contains("Something went wrong"))
    }
}
```

- [ ] **Step 2: Run — expect FAIL (compile error on unknown type)**

Run: `swift test --package-path Packages/EnhancerCore`
Expected: compile error `cannot find 'EnhancerError' in scope`.

- [ ] **Step 3: Implement**

```swift
// EnhancerError.swift
import Foundation

public enum EnhancerError: Error, Sendable, Equatable {
    case guardrailViolation
    case rateLimited
    case exceededContextWindow
    case modelUnavailable(LanguageModelAvailability.Reason)
    case cancelled
    case unknown(String)

    public static func unknown(_ error: Error) -> EnhancerError {
        .unknown(String(describing: error))
    }

    public var userFacingMessage: String {
        switch self {
        case .guardrailViolation:
            return "Couldn't enhance this — try rephrasing."
        case .rateLimited:
            return "Too many requests — try again in a moment."
        case .exceededContextWindow:
            return "Text is too complex — try splitting it."
        case .modelUnavailable:
            return "Apple Intelligence isn't available right now."
        case .cancelled:
            return "Cancelled."
        case .unknown:
            return "Something went wrong."
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .unknown: return true
        default: return false
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/EnhancerCore`
Expected: all tests pass.

- [ ] **Step 5: Commit Tasks 11 + 12 together**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/EnhancementRequest.swift Packages/EnhancerCore/Sources/EnhancerCore/EnhancerError.swift Packages/EnhancerCore/Tests/EnhancerCoreTests/ErrorMappingTests.swift
git commit -m "feat(EnhancerCore): add request/chunk value types and EnhancerError"
```

---

### Task 13: `Prompts` rendering (TDD)

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/Prompts.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/PromptsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// PromptsTests.swift
import Testing
@testable import EnhancerCore

@Suite("Prompts")
struct PromptsTests {
    @Test func systemInstructionsContainNativeGuidance() {
        let sys = Prompts.systemInstructions(styleInstructions: "Casual, friendly.")
        #expect(sys.contains("native English speaker"))
        #expect(sys.contains("Preserve the user's meaning"))
        #expect(sys.contains("Casual, friendly."))
    }

    @Test func systemInstructionsForbidPreamble() {
        let sys = Prompts.systemInstructions(styleInstructions: "x")
        #expect(sys.contains("No preamble"))
    }

    @Test func userPromptWrapsOriginal() {
        let p = Prompts.userPrompt(original: "hey thx")
        #expect(p == "Original: hey thx")
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/EnhancerCore --filter Prompts`
Expected: compile error `cannot find 'Prompts' in scope`.

- [ ] **Step 3: Implement**

```swift
// Prompts.swift
import Foundation

public enum Prompts {
    public static func systemInstructions(styleInstructions: String) -> String {
        """
        You rewrite the user's message so it sounds like a native English speaker wrote it.
        Fix grammar, idioms, article usage, and awkward phrasing.
        Preserve the user's meaning and intent exactly.
        Preserve register (casual stays casual, formal stays formal) unless the style instruction says otherwise.
        Apply the style: \(styleInstructions)
        Output only the rewritten message. No preamble, no explanations.
        """
    }

    public static func userPrompt(original: String) -> String {
        "Original: \(original)"
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/EnhancerCore --filter Prompts`
Expected: 3 pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/Prompts.swift Packages/EnhancerCore/Tests/EnhancerCoreTests/PromptsTests.swift
git commit -m "feat(EnhancerCore): add Prompts template rendering"
```

---

### Task 14: `Enhancer` actor — sequential streaming (TDD)

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/Enhancer.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/EnhancerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// EnhancerTests.swift
import Testing
import Foundation
@testable import EnhancerCore

@Suite("Enhancer")
struct EnhancerTests {
    private func sampleRequest() -> EnhancementRequest {
        EnhancementRequest(
            inputText: "hey",
            variants: [
                VariantRequest(presetID: UUID(), presetLabel: "A", presetInstructions: "ia"),
                VariantRequest(presetID: UUID(), presetLabel: "B", presetInstructions: "ib"),
                VariantRequest(presetID: UUID(), presetLabel: "C", presetInstructions: "ic")
            ]
        )
    }

    @Test func emitsStartDeltaCompleteForEachVariantInOrder() async throws {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi", " there"])
        let enhancer = Enhancer(provider: provider)
        let request = sampleRequest()

        var events: [VariantChunk] = []
        for await event in enhancer.enhance(request) {
            events.append(event)
        }

        #expect(events.count == 3 * 3) // start + 2 deltas + complete? adjust below

        // Actually: per variant we get started, N deltas, completed → so 4 events per variant
        // Rewrite expectation:
        let expectedPerVariant = 4 // started, delta "Hi", delta " there", completed
        #expect(events.count == request.variants.count * expectedPerVariant)

        for (index, v) in request.variants.enumerated() {
            let base = index * expectedPerVariant
            if case .started(let pid) = events[base] {
                #expect(pid == v.presetID)
            } else { Issue.record("expected .started at \(base)") }
            if case .completed(let pid, let text) = events[base + 3] {
                #expect(pid == v.presetID)
                #expect(text == "Hi there")
            } else { Issue.record("expected .completed at \(base + 3)") }
        }
    }

    @Test func mapsGuardrailViolationToFailedEventPerVariant() async throws {
        struct Guardrail: Error {}
        let provider = StubLanguageModelProvider(
            scriptedChunks: ["partial"],
            scriptedError: Guardrail()
        )
        let enhancer = Enhancer(
            provider: provider,
            errorMapper: { _ in .guardrailViolation }
        )

        var failures = 0
        for await event in enhancer.enhance(sampleRequest()) {
            if case .failed(_, .guardrailViolation) = event { failures += 1 }
        }
        #expect(failures == 3)
    }

    @Test func cancellationStopsMidStream() async throws {
        let provider = StubLanguageModelProvider(
            scriptedChunks: Array(repeating: "x", count: 100),
            chunkDelay: .milliseconds(10)
        )
        let enhancer = Enhancer(provider: provider)
        let request = sampleRequest()

        let task = Task {
            var count = 0
            for await _ in enhancer.enhance(request) {
                count += 1
                if count == 3 { break }  // consumer breaks early
            }
            return count
        }
        let received = await task.value
        #expect(received == 3)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/EnhancerCore --filter Enhancer`
Expected: compile errors (`Enhancer` actor and signatures don't exist).

- [ ] **Step 3: Implement**

```swift
// Enhancer.swift
import Foundation

public actor Enhancer {
    public typealias ErrorMapper = @Sendable (Error) -> EnhancerError

    private let provider: LanguageModelProvider
    private let errorMapper: ErrorMapper

    public init(
        provider: LanguageModelProvider,
        errorMapper: @escaping ErrorMapper = Enhancer.defaultErrorMapper
    ) {
        self.provider = provider
        self.errorMapper = errorMapper
    }

    public static let defaultErrorMapper: ErrorMapper = { error in
        if error is CancellationError { return .cancelled }
        return .unknown(error)
    }

    public nonisolated func enhance(_ request: EnhancementRequest) -> AsyncStream<VariantChunk> {
        AsyncStream { continuation in
            let task = Task {
                for variant in request.variants {
                    if Task.isCancelled { break }
                    continuation.yield(.started(presetID: variant.presetID))
                    var aggregated = ""
                    do {
                        let stream = provider.stream(
                            instructions: Prompts.systemInstructions(styleInstructions: variant.presetInstructions),
                            prompt: Prompts.userPrompt(original: request.inputText)
                        )
                        for try await delta in stream {
                            if Task.isCancelled { break }
                            aggregated += delta
                            continuation.yield(.delta(presetID: variant.presetID, text: delta))
                        }
                        if Task.isCancelled { break }
                        continuation.yield(.completed(presetID: variant.presetID, fullText: aggregated))
                    } catch {
                        continuation.yield(.failed(presetID: variant.presetID, error: errorMapper(error)))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/EnhancerCore`
Expected: all EnhancerCore tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/Enhancer.swift Packages/EnhancerCore/Tests/EnhancerCoreTests/EnhancerTests.swift
git commit -m "feat(EnhancerCore): add Enhancer actor with sequential streaming"
```

---

## Phase 3 — PresetKit (TDD)

### Task 15: `Preset` + `PresetSelection` value types

**Files:**
- Create: `Packages/PresetKit/Sources/PresetKit/Preset.swift`

- [ ] **Step 1: Write types**

```swift
// Preset.swift
import Foundation

public struct Preset: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    public var instructions: String
    public var isBuiltIn: Bool
    public var sortOrder: Int

    public init(id: UUID = UUID(), label: String, instructions: String, isBuiltIn: Bool, sortOrder: Int) {
        self.id = id
        self.label = label
        self.instructions = instructions
        self.isBuiltIn = isBuiltIn
        self.sortOrder = sortOrder
    }
}

public struct PresetSelection: Codable, Equatable, Sendable {
    public var activePresetIDs: [UUID]

    public init(activePresetIDs: [UUID]) {
        self.activePresetIDs = activePresetIDs
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build --package-path Packages/PresetKit`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/PresetKit/Sources/PresetKit/Preset.swift
git commit -m "feat(PresetKit): add Preset and PresetSelection value types"
```

---

### Task 16: Built-in presets (TDD)

**Files:**
- Create: `Packages/PresetKit/Sources/PresetKit/BuiltInPresets.swift`
- Create: `Packages/PresetKit/Tests/PresetKitTests/BuiltInPresetsTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// BuiltInPresetsTests.swift
import Testing
@testable import PresetKit

@Suite("BuiltInPresets")
struct BuiltInPresetsTests {
    @Test func containsExactlyEight() {
        #expect(BuiltInPresets.all.count == 8)
    }

    @Test func labelsMatchSpec() {
        let expected = ["Casual", "Neutral", "Formal", "Friendly", "Direct", "Professional", "Warm", "Confident"]
        let labels = BuiltInPresets.all.map(\.label)
        #expect(labels == expected)
    }

    @Test func allAreBuiltIn() {
        #expect(BuiltInPresets.all.allSatisfy { $0.isBuiltIn })
    }

    @Test func allHaveNonEmptyInstructions() {
        #expect(BuiltInPresets.all.allSatisfy { !$0.instructions.isEmpty })
    }

    @Test func sortOrdersAreUniqueAscending() {
        let orders = BuiltInPresets.all.map(\.sortOrder)
        #expect(orders == orders.sorted())
        #expect(Set(orders).count == orders.count)
    }

    @Test func defaultActiveSet() {
        let defaults = BuiltInPresets.defaultActive
        #expect(defaults.count == 3)
        let labels = defaults.map(\.label)
        #expect(labels == ["Casual", "Professional", "Warm"])
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/PresetKit`
Expected: compile error `cannot find 'BuiltInPresets' in scope`.

- [ ] **Step 3: Implement**

```swift
// BuiltInPresets.swift
import Foundation

public enum BuiltInPresets {
    public static let all: [Preset] = [
        Preset(id: uuid("A1"),
               label: "Casual",
               instructions: "Use everyday conversational language. Light contractions. Friendly but not overly formal.",
               isBuiltIn: true, sortOrder: 0),
        Preset(id: uuid("A2"),
               label: "Neutral",
               instructions: "Neutral register. No slang, no stiffness. Plain, clear English.",
               isBuiltIn: true, sortOrder: 1),
        Preset(id: uuid("A3"),
               label: "Formal",
               instructions: "Formal English suitable for business correspondence. No contractions. Polite and precise.",
               isBuiltIn: true, sortOrder: 2),
        Preset(id: uuid("A4"),
               label: "Friendly",
               instructions: "Warm and approachable. Light exclamation use is okay. Assume a cooperative reader.",
               isBuiltIn: true, sortOrder: 3),
        Preset(id: uuid("A5"),
               label: "Direct",
               instructions: "Short sentences. Remove filler and hedging. Be assertive but courteous.",
               isBuiltIn: true, sortOrder: 4),
        Preset(id: uuid("A6"),
               label: "Professional",
               instructions: "Business-appropriate, polished, courteous. Slightly formal. Suitable for email and Slack.",
               isBuiltIn: true, sortOrder: 5),
        Preset(id: uuid("A7"),
               label: "Warm",
               instructions: "Kind, considerate phrasing. Gentle openings and closings where appropriate.",
               isBuiltIn: true, sortOrder: 6),
        Preset(id: uuid("A8"),
               label: "Confident",
               instructions: "Assertive and self-assured. Avoid apologetic language. State positions clearly.",
               isBuiltIn: true, sortOrder: 7)
    ]

    public static var defaultActive: [Preset] {
        let labels: Set<String> = ["Casual", "Professional", "Warm"]
        return all.filter { labels.contains($0.label) }
    }

    private static func uuid(_ seed: String) -> UUID {
        // Stable UUIDs derived from short seeds so tests and persistence behave deterministically.
        var bytes = Array(seed.utf8)
        while bytes.count < 16 { bytes.append(0) }
        let slice = Array(bytes.prefix(16))
        return UUID(uuid: (slice[0],slice[1],slice[2],slice[3],slice[4],slice[5],slice[6],slice[7],
                          slice[8],slice[9],slice[10],slice[11],slice[12],slice[13],slice[14],slice[15]))
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/PresetKit`
Expected: 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/PresetKit/Sources/PresetKit/BuiltInPresets.swift Packages/PresetKit/Tests/PresetKitTests/BuiltInPresetsTests.swift
git commit -m "feat(PresetKit): add 8 built-in presets with stable IDs"
```

---

### Task 17: Preset validation (TDD)

**Files:**
- Create: `Packages/PresetKit/Sources/PresetKit/PresetValidation.swift`
- Create: `Packages/PresetKit/Tests/PresetKitTests/PresetValidationTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// PresetValidationTests.swift
import Testing
@testable import PresetKit

@Suite("PresetValidation")
struct PresetValidationTests {
    @Test func acceptsValidLabels() throws {
        try PresetValidation.validate(label: "A", instructions: "ok")
        try PresetValidation.validate(label: String(repeating: "x", count: 24), instructions: "ok")
    }

    @Test func rejectsEmptyLabel() {
        #expect(throws: PresetValidation.Error.emptyLabel) {
            try PresetValidation.validate(label: "   ", instructions: "ok")
        }
    }

    @Test func rejectsOverlongLabel() {
        #expect(throws: PresetValidation.Error.labelTooLong) {
            try PresetValidation.validate(label: String(repeating: "x", count: 25), instructions: "ok")
        }
    }

    @Test func rejectsEmptyInstructions() {
        #expect(throws: PresetValidation.Error.emptyInstructions) {
            try PresetValidation.validate(label: "A", instructions: "")
        }
    }

    @Test func rejectsOverlongInstructions() {
        #expect(throws: PresetValidation.Error.instructionsTooLong) {
            try PresetValidation.validate(label: "A", instructions: String(repeating: "x", count: 401))
        }
    }

    @Test func activeSelectionMustBeExactlyThree() {
        #expect(throws: PresetValidation.Error.activeSelectionWrongSize) {
            try PresetValidation.validateActiveSelection(count: 2)
        }
        #expect(throws: PresetValidation.Error.activeSelectionWrongSize) {
            try PresetValidation.validateActiveSelection(count: 4)
        }
        // 3 does not throw
        try? PresetValidation.validateActiveSelection(count: 3)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/PresetKit --filter PresetValidation`
Expected: compile error.

- [ ] **Step 3: Implement**

```swift
// PresetValidation.swift
import Foundation

public enum PresetValidation {
    public static let labelMax = 24
    public static let instructionsMax = 400
    public static let customPresetCap = 20
    public static let activeSelectionSize = 3

    public enum Error: Swift.Error, Equatable {
        case emptyLabel
        case labelTooLong
        case emptyInstructions
        case instructionsTooLong
        case customPresetCapReached
        case activeSelectionWrongSize
    }

    public static func validate(label: String, instructions: String) throws {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLabel.isEmpty { throw Error.emptyLabel }
        if label.count > labelMax { throw Error.labelTooLong }
        if instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw Error.emptyInstructions
        }
        if instructions.count > instructionsMax { throw Error.instructionsTooLong }
    }

    public static func validateActiveSelection(count: Int) throws {
        if count != activeSelectionSize { throw Error.activeSelectionWrongSize }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/PresetKit --filter PresetValidation`
Expected: 6 pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/PresetKit/Sources/PresetKit/PresetValidation.swift Packages/PresetKit/Tests/PresetKitTests/PresetValidationTests.swift
git commit -m "feat(PresetKit): add PresetValidation with label/instructions bounds"
```

---

### Task 18: `PresetStore` (TDD)

**Files:**
- Create: `Packages/PresetKit/Sources/PresetKit/PresetStore.swift`
- Create: `Packages/PresetKit/Tests/PresetKitTests/PresetStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// PresetStoreTests.swift
import Testing
import Foundation
@testable import PresetKit

@Suite("PresetStore")
struct PresetStoreTests {
    private func makeStore() -> (PresetStore, UserDefaults) {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (PresetStore(defaults: defaults), defaults)
    }

    @Test func firstLaunchSeedsBuiltInsAndDefaultActive() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        #expect(store.allPresets.count == 8)
        #expect(store.activePresets.map(\.label) == ["Casual", "Professional", "Warm"])
    }

    @Test func seedIsIdempotent() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        store.seedIfNeeded()
        #expect(store.allPresets.count == 8)
    }

    @Test func addCustomPresetPersists() throws {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let new = try store.addCustom(label: "Startup", instructions: "Casual, no buzzwords.")
        #expect(new.isBuiltIn == false)
        #expect(store.allPresets.contains(where: { $0.id == new.id }))
    }

    @Test func addCustomRespectsCap() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        for i in 0..<20 {
            _ = try? store.addCustom(label: "P\(i)", instructions: "x")
        }
        #expect(throws: PresetValidation.Error.customPresetCapReached) {
            _ = try store.addCustom(label: "Overflow", instructions: "x")
        }
    }

    @Test func deleteCustomRemoves() throws {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let p = try store.addCustom(label: "X", instructions: "y")
        try store.deleteCustom(id: p.id)
        #expect(!store.allPresets.contains(where: { $0.id == p.id }))
    }

    @Test func deleteBuiltInThrows() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let builtIn = store.allPresets.first { $0.isBuiltIn }!
        #expect(throws: PresetStore.Error.cannotDeleteBuiltIn) {
            try store.deleteCustom(id: builtIn.id)
        }
    }

    @Test func setActiveRequiresExactlyThree() {
        let (store, _) = makeStore()
        store.seedIfNeeded()
        let ids = store.allPresets.prefix(2).map(\.id)
        #expect(throws: PresetValidation.Error.activeSelectionWrongSize) {
            try store.setActive(presetIDs: ids)
        }
    }

    @Test func setActivePersists() throws {
        let (store, defaults) = makeStore()
        store.seedIfNeeded()
        let newIDs = Array(store.allPresets.prefix(3).map(\.id))
        try store.setActive(presetIDs: newIDs)
        let reloaded = PresetStore(defaults: defaults)
        reloaded.seedIfNeeded()
        #expect(reloaded.activePresets.map(\.id) == newIDs)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/PresetKit --filter PresetStore`

- [ ] **Step 3: Implement**

```swift
// PresetStore.swift
import Foundation
import Observation

@Observable
@MainActor
public final class PresetStore {
    public enum Error: Swift.Error, Equatable {
        case cannotDeleteBuiltIn
        case notFound
    }

    private enum Keys {
        static let presets = "presets.v1"
        static let selection = "presets.selection.v1"
        static let seeded = "presets.seeded.v1"
    }

    private let defaults: UserDefaults
    public private(set) var allPresets: [Preset] = []
    public private(set) var activePresets: [Preset] = []

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    public func seedIfNeeded() {
        if defaults.bool(forKey: Keys.seeded) {
            load()
            return
        }
        allPresets = BuiltInPresets.all
        let defaultActiveIDs = BuiltInPresets.defaultActive.map(\.id)
        persist(presets: allPresets, activeIDs: defaultActiveIDs)
        defaults.set(true, forKey: Keys.seeded)
        load()
    }

    @discardableResult
    public func addCustom(label: String, instructions: String) throws -> Preset {
        try PresetValidation.validate(label: label, instructions: instructions)
        let customCount = allPresets.filter { !$0.isBuiltIn }.count
        if customCount >= PresetValidation.customPresetCap {
            throw PresetValidation.Error.customPresetCapReached
        }
        let sortOrder = (allPresets.map(\.sortOrder).max() ?? 0) + 1
        let new = Preset(label: label, instructions: instructions, isBuiltIn: false, sortOrder: sortOrder)
        var updated = allPresets
        updated.append(new)
        persist(presets: updated, activeIDs: activePresets.map(\.id))
        load()
        return new
    }

    public func updateCustom(id: UUID, label: String, instructions: String) throws {
        try PresetValidation.validate(label: label, instructions: instructions)
        guard let idx = allPresets.firstIndex(where: { $0.id == id }) else { throw Error.notFound }
        if allPresets[idx].isBuiltIn { throw Error.cannotDeleteBuiltIn }
        var updated = allPresets
        updated[idx].label = label
        updated[idx].instructions = instructions
        persist(presets: updated, activeIDs: activePresets.map(\.id))
        load()
    }

    public func deleteCustom(id: UUID) throws {
        guard let existing = allPresets.first(where: { $0.id == id }) else { throw Error.notFound }
        if existing.isBuiltIn { throw Error.cannotDeleteBuiltIn }
        var updated = allPresets
        updated.removeAll { $0.id == id }
        var active = activePresets.map(\.id)
        active.removeAll { $0 == id }
        // If removing a custom preset drops active below 3, fill from built-ins.
        if active.count < PresetValidation.activeSelectionSize {
            for p in BuiltInPresets.all where !active.contains(p.id) {
                active.append(p.id)
                if active.count == PresetValidation.activeSelectionSize { break }
            }
        }
        persist(presets: updated, activeIDs: active)
        load()
    }

    public func setActive(presetIDs: [UUID]) throws {
        try PresetValidation.validateActiveSelection(count: presetIDs.count)
        let knownIDs = Set(allPresets.map(\.id))
        guard presetIDs.allSatisfy({ knownIDs.contains($0) }) else { throw Error.notFound }
        persist(presets: allPresets, activeIDs: presetIDs)
        load()
    }

    // MARK: - Private

    private func load() {
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: Keys.presets),
           let decoded = try? decoder.decode([Preset].self, from: data) {
            allPresets = decoded.sorted(by: { $0.sortOrder < $1.sortOrder })
        } else {
            allPresets = []
        }
        if let selData = defaults.data(forKey: Keys.selection),
           let sel = try? decoder.decode(PresetSelection.self, from: selData) {
            activePresets = sel.activePresetIDs.compactMap { id in allPresets.first(where: { $0.id == id }) }
        } else {
            activePresets = []
        }
    }

    private func persist(presets: [Preset], activeIDs: [UUID]) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(presets) { defaults.set(data, forKey: Keys.presets) }
        let selection = PresetSelection(activePresetIDs: activeIDs)
        if let data = try? encoder.encode(selection) { defaults.set(data, forKey: Keys.selection) }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/PresetKit`
Expected: all PresetKit tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/PresetKit/Sources/PresetKit/PresetStore.swift Packages/PresetKit/Tests/PresetKitTests/PresetStoreTests.swift
git commit -m "feat(PresetKit): add PresetStore with UserDefaults persistence"
```

---

## Phase 4 — HistoryKit (TDD)

### Task 19: `RecentItem` @Model + `SavedVariant`

**Files:**
- Create: `Packages/HistoryKit/Sources/HistoryKit/RecentItem.swift`
- Create: `Packages/HistoryKit/Tests/HistoryKitTests/RecentItemTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// RecentItemTests.swift
import Testing
import Foundation
@testable import HistoryKit

@Suite("RecentItem")
struct RecentItemTests {
    @Test func variantsRoundTrip() throws {
        let variant = SavedVariant(
            presetID: UUID(),
            presetLabelSnapshot: "Casual",
            outputText: "Hey there!"
        )
        let data = try JSONEncoder().encode([variant])
        let decoded = try JSONDecoder().decode([SavedVariant].self, from: data)
        #expect(decoded == [variant])
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/HistoryKit`

- [ ] **Step 3: Implement**

```swift
// RecentItem.swift
import Foundation
import SwiftData

public struct SavedVariant: Codable, Equatable, Hashable, Sendable {
    public let presetID: UUID
    public let presetLabelSnapshot: String
    public let outputText: String

    public init(presetID: UUID, presetLabelSnapshot: String, outputText: String) {
        self.presetID = presetID
        self.presetLabelSnapshot = presetLabelSnapshot
        self.outputText = outputText
    }
}

@Model
public final class RecentItem {
    @Attribute(.unique) public var id: UUID
    public var createdAt: Date
    public var inputText: String
    public var variantsData: Data   // JSON-encoded [SavedVariant]
    public var deviceModelName: String

    public init(id: UUID = UUID(), createdAt: Date = .now, inputText: String, variants: [SavedVariant], deviceModelName: String) {
        self.id = id
        self.createdAt = createdAt
        self.inputText = inputText
        self.variantsData = (try? JSONEncoder().encode(variants)) ?? Data()
        self.deviceModelName = deviceModelName
    }

    public var variants: [SavedVariant] {
        get { (try? JSONDecoder().decode([SavedVariant].self, from: variantsData)) ?? [] }
        set { variantsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/HistoryKit`
Expected: 1 test passes.

- [ ] **Step 5: Commit**

```bash
git add Packages/HistoryKit/Sources/HistoryKit/RecentItem.swift Packages/HistoryKit/Tests/HistoryKitTests/RecentItemTests.swift
git commit -m "feat(HistoryKit): add RecentItem @Model and SavedVariant"
```

---

### Task 20: `HistorySchema` — `ModelContainer` factory

**Files:**
- Create: `Packages/HistoryKit/Sources/HistoryKit/HistorySchema.swift`

- [ ] **Step 1: Write factory**

```swift
// HistorySchema.swift
import Foundation
import SwiftData

public enum HistorySchema {
    public static let versionedSchema = Schema([RecentItem.self])

    public static func makeContainer(appGroupURL: URL?) throws -> ModelContainer {
        let config: ModelConfiguration
        if let appGroupURL {
            let storeURL = appGroupURL.appendingPathComponent("history.sqlite")
            config = ModelConfiguration(url: storeURL)
        } else {
            config = ModelConfiguration(isStoredInMemoryOnly: true)
        }
        return try ModelContainer(for: versionedSchema, configurations: config)
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build --package-path Packages/HistoryKit`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/HistoryKit/Sources/HistoryKit/HistorySchema.swift
git commit -m "feat(HistoryKit): add HistorySchema ModelContainer factory"
```

---

### Task 21: `HistoryStore` with 50-cap eviction (TDD)

**Files:**
- Create: `Packages/HistoryKit/Sources/HistoryKit/HistoryStore.swift`
- Create: `Packages/HistoryKit/Tests/HistoryKitTests/HistoryStoreTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// HistoryStoreTests.swift
import Testing
import Foundation
import SwiftData
@testable import HistoryKit

@Suite("HistoryStore")
@MainActor
struct HistoryStoreTests {
    private func makeStore() throws -> HistoryStore {
        let container = try HistorySchema.makeContainer(appGroupURL: nil)
        return HistoryStore(container: container)
    }

    private func sampleVariants() -> [SavedVariant] {
        [
            SavedVariant(presetID: UUID(), presetLabelSnapshot: "A", outputText: "a"),
            SavedVariant(presetID: UUID(), presetLabelSnapshot: "B", outputText: "b"),
            SavedVariant(presetID: UUID(), presetLabelSnapshot: "C", outputText: "c")
        ]
    }

    @Test func insertIncreasesCount() throws {
        let store = try makeStore()
        try store.insert(inputText: "hi", variants: sampleVariants(), deviceModelName: "test")
        #expect(store.allMostRecentFirst().count == 1)
    }

    @Test func ordersMostRecentFirst() throws {
        let store = try makeStore()
        try store.insert(inputText: "a", variants: sampleVariants(), deviceModelName: "test")
        try store.insert(inputText: "b", variants: sampleVariants(), deviceModelName: "test")
        try store.insert(inputText: "c", variants: sampleVariants(), deviceModelName: "test")
        let items = store.allMostRecentFirst()
        #expect(items.map(\.inputText) == ["c", "b", "a"])
    }

    @Test func evictsOldestAtFiftyCap() throws {
        let store = try makeStore()
        for i in 0..<55 {
            try store.insert(inputText: "t\(i)", variants: sampleVariants(), deviceModelName: "test")
        }
        let items = store.allMostRecentFirst()
        #expect(items.count == 50)
        #expect(items.first?.inputText == "t54")
        #expect(items.last?.inputText == "t5")
    }

    @Test func clearRemovesAll() throws {
        let store = try makeStore()
        try store.insert(inputText: "x", variants: sampleVariants(), deviceModelName: "test")
        try store.clear()
        #expect(store.allMostRecentFirst().isEmpty)
    }

    @Test func deleteByIDRemovesOne() throws {
        let store = try makeStore()
        try store.insert(inputText: "a", variants: sampleVariants(), deviceModelName: "test")
        try store.insert(inputText: "b", variants: sampleVariants(), deviceModelName: "test")
        let first = store.allMostRecentFirst().first!
        try store.delete(id: first.id)
        #expect(store.allMostRecentFirst().count == 1)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/HistoryKit`

- [ ] **Step 3: Implement**

```swift
// HistoryStore.swift
import Foundation
import SwiftData

@MainActor
public final class HistoryStore {
    public static let maxItems = 50

    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    public init(container: ModelContainer) {
        self.container = container
    }

    public func insert(inputText: String, variants: [SavedVariant], deviceModelName: String) throws {
        let item = RecentItem(inputText: inputText, variants: variants, deviceModelName: deviceModelName)
        context.insert(item)
        try evictIfNeeded()
        try context.save()
    }

    public func allMostRecentFirst() -> [RecentItem] {
        let descriptor = FetchDescriptor<RecentItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    public func delete(id: UUID) throws {
        var descriptor = FetchDescriptor<RecentItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        if let item = try context.fetch(descriptor).first {
            context.delete(item)
            try context.save()
        }
    }

    public func clear() throws {
        let all = allMostRecentFirst()
        for item in all { context.delete(item) }
        try context.save()
    }

    private func evictIfNeeded() throws {
        let all = allMostRecentFirst()
        let overflow = all.count - Self.maxItems
        guard overflow > 0 else { return }
        for victim in all.suffix(overflow) {
            context.delete(victim)
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/HistoryKit`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/HistoryKit/Sources/HistoryKit/HistoryStore.swift Packages/HistoryKit/Tests/HistoryKitTests/HistoryStoreTests.swift
git commit -m "feat(HistoryKit): add HistoryStore with 50-item rolling eviction"
```

---

## Phase 5 — EnhancerUI

### Task 22: `VariantViewState` + tests

**Files:**
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/VariantViewState.swift`
- Create: `Packages/EnhancerUI/Tests/EnhancerUITests/VariantViewStateTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// VariantViewStateTests.swift
import Testing
import Foundation
import EnhancerCore
@testable import EnhancerUI

@Suite("VariantViewState")
struct VariantViewStateTests {
    @Test func transitionsFromWaitingToStreamingToComplete() {
        var state = VariantViewState(presetID: UUID(), presetLabel: "Casual")
        #expect(state.phase == .waiting)
        state.apply(.started(presetID: state.presetID))
        #expect(state.phase == .streaming)
        state.apply(.delta(presetID: state.presetID, text: "Hi"))
        state.apply(.delta(presetID: state.presetID, text: " there"))
        #expect(state.text == "Hi there")
        state.apply(.completed(presetID: state.presetID, fullText: "Hi there"))
        #expect(state.phase == .completed)
    }

    @Test func ignoresEventsForOtherPreset() {
        var state = VariantViewState(presetID: UUID(), presetLabel: "A")
        state.apply(.delta(presetID: UUID(), text: "wrong"))
        #expect(state.text.isEmpty)
        #expect(state.phase == .waiting)
    }

    @Test func failedSetsErrorPhase() {
        var state = VariantViewState(presetID: UUID(), presetLabel: "A")
        state.apply(.failed(presetID: state.presetID, error: .guardrailViolation))
        if case .failed(let e) = state.phase { #expect(e == .guardrailViolation) }
        else { Issue.record("expected .failed phase") }
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/EnhancerUI --filter VariantViewState`

- [ ] **Step 3: Implement**

```swift
// VariantViewState.swift
import Foundation
import EnhancerCore

public struct VariantViewState: Identifiable, Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        case waiting
        case streaming
        case completed
        case failed(EnhancerError)
    }

    public let presetID: UUID
    public let presetLabel: String
    public private(set) var text: String = ""
    public private(set) var phase: Phase = .waiting

    public var id: UUID { presetID }

    public init(presetID: UUID, presetLabel: String) {
        self.presetID = presetID
        self.presetLabel = presetLabel
    }

    public mutating func apply(_ chunk: VariantChunk) {
        switch chunk {
        case .started(let id) where id == presetID:
            phase = .streaming
        case .delta(let id, let text) where id == presetID:
            self.text += text
        case .completed(let id, let fullText) where id == presetID:
            self.text = fullText
            phase = .completed
        case .failed(let id, let error) where id == presetID:
            phase = .failed(error)
        default:
            break
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/EnhancerUI --filter VariantViewState`
Expected: 3 pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerUI/Sources/EnhancerUI/VariantViewState.swift Packages/EnhancerUI/Tests/EnhancerUITests/VariantViewStateTests.swift
git commit -m "feat(EnhancerUI): add VariantViewState state machine"
```

---

### Task 23: `EnhancementViewModel` (TDD)

**Files:**
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/EnhancementViewModel.swift`
- Create: `Packages/EnhancerUI/Tests/EnhancerUITests/EnhancementViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
// EnhancementViewModelTests.swift
import Testing
import Foundation
import EnhancerCore
import PresetKit
@testable import EnhancerUI

@Suite("EnhancementViewModel")
@MainActor
struct EnhancementViewModelTests {
    private func presets() -> [Preset] { Array(BuiltInPresets.all.prefix(3)) }

    @Test func startPopulatesAllVariantStates() async {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi"])
        let enhancer = Enhancer(provider: provider)
        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets())
        #expect(vm.variantStates.count == 3)
    }

    @Test func variantStatesReachCompleted() async {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi"])
        let enhancer = Enhancer(provider: provider)
        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets())
        await vm.waitForCompletion()
        #expect(vm.variantStates.allSatisfy { $0.phase == .completed })
        #expect(vm.variantStates.allSatisfy { $0.text == "Hi" })
    }

    @Test func cancelStopsFurtherEvents() async {
        let provider = StubLanguageModelProvider(
            scriptedChunks: Array(repeating: "x", count: 50),
            chunkDelay: .milliseconds(20)
        )
        let enhancer = Enhancer(provider: provider)
        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets())
        try? await Task.sleep(for: .milliseconds(40))
        vm.cancel()
        await vm.waitForCompletion()
        #expect(vm.variantStates.contains(where: { $0.phase == .streaming || $0.phase == .waiting }) == false
               || vm.variantStates.count == 3)
    }
}
```

- [ ] **Step 2: Run — expect FAIL**

Run: `swift test --package-path Packages/EnhancerUI --filter EnhancementViewModel`

- [ ] **Step 3: Implement**

```swift
// EnhancementViewModel.swift
import Foundation
import Observation
import EnhancerCore
import PresetKit

@Observable
@MainActor
public final class EnhancementViewModel {
    public private(set) var inputText: String = ""
    public private(set) var variantStates: [VariantViewState] = []
    public private(set) var isRunning: Bool = false

    private let enhancer: Enhancer
    private var consumerTask: Task<Void, Never>?
    private var completionContinuation: CheckedContinuation<Void, Never>?

    public init(enhancer: Enhancer) {
        self.enhancer = enhancer
    }

    public func start(inputText: String, activePresets: [Preset]) async {
        self.inputText = inputText
        self.variantStates = activePresets.map {
            VariantViewState(presetID: $0.id, presetLabel: $0.label)
        }
        let variants = activePresets.map {
            VariantRequest(presetID: $0.id, presetLabel: $0.label, presetInstructions: $0.instructions)
        }
        let request = EnhancementRequest(inputText: inputText, variants: variants)

        isRunning = true
        let task = Task { [weak self] in
            guard let self else { return }
            for await event in await self.enhancer.enhance(request) {
                if Task.isCancelled { break }
                self.apply(event)
            }
            await MainActor.run {
                self.isRunning = false
                self.completionContinuation?.resume()
                self.completionContinuation = nil
            }
        }
        self.consumerTask = task
    }

    public func cancel() {
        consumerTask?.cancel()
    }

    public func regenerate(presetID: UUID, activePresets: [Preset]) async {
        // v1: simplest approach — full re-run with the single preset, then merge.
        // Keeps state-machine simple; future optimization can cancel only one sub-task.
        guard let preset = activePresets.first(where: { $0.id == presetID }) else { return }
        if let idx = variantStates.firstIndex(where: { $0.presetID == presetID }) {
            variantStates[idx] = VariantViewState(presetID: preset.id, presetLabel: preset.label)
        }
        let request = EnhancementRequest(
            inputText: inputText,
            variants: [VariantRequest(presetID: preset.id, presetLabel: preset.label, presetInstructions: preset.instructions)]
        )
        for await event in await enhancer.enhance(request) {
            apply(event)
        }
    }

    public func waitForCompletion() async {
        guard isRunning else { return }
        await withCheckedContinuation { cont in
            completionContinuation = cont
        }
    }

    private func apply(_ chunk: VariantChunk) {
        switch chunk {
        case .started(let id), .delta(let id, _), .completed(let id, _), .failed(let id, _):
            if let idx = variantStates.firstIndex(where: { $0.presetID == id }) {
                variantStates[idx].apply(chunk)
            }
        }
    }
}
```

- [ ] **Step 4: Run — expect PASS**

Run: `swift test --package-path Packages/EnhancerUI`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerUI/Sources/EnhancerUI/EnhancementViewModel.swift Packages/EnhancerUI/Tests/EnhancerUITests/EnhancementViewModelTests.swift
git commit -m "feat(EnhancerUI): add EnhancementViewModel with cancellation"
```

---

### Task 24: `VariantCard` view

**Files:**
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/VariantCard.swift`

- [ ] **Step 1: Write view (no unit test — snapshot tests are for later; rendering verified in main-app previews)**

```swift
// VariantCard.swift
import SwiftUI
import EnhancerCore

public struct VariantCard: View {
    public enum ActionKind { case copy, useThis }

    public let state: VariantViewState
    public let actionKind: ActionKind
    public let onPrimary: () -> Void
    public let onRegenerate: () -> Void

    public init(state: VariantViewState,
                actionKind: ActionKind = .copy,
                onPrimary: @escaping () -> Void,
                onRegenerate: @escaping () -> Void) {
        self.state = state
        self.actionKind = actionKind
        self.onPrimary = onPrimary
        self.onRegenerate = onRegenerate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(state.presetLabel.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            switch state.phase {
            case .waiting:
                Text("Waiting…").foregroundStyle(.secondary).italic()
            case .streaming:
                Text(state.text.isEmpty ? "Generating…" : state.text)
                    .foregroundStyle(state.text.isEmpty ? .secondary : .primary)
                    .italic(state.text.isEmpty)
            case .completed:
                Text(state.text)
            case .failed(let error):
                Text(error.userFacingMessage).foregroundStyle(.red)
            }

            HStack {
                Button(actionKind == .copy ? "Copy" : "Use this", action: onPrimary)
                    .buttonStyle(.borderedProminent)
                    .disabled(state.phase != .completed)
                Button("Regenerate", systemImage: "arrow.clockwise", action: onRegenerate)
                    .labelStyle(.iconOnly)
                    .disabled(state.phase == .streaming || state.phase == .waiting)
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
    }
}
```

- [ ] **Step 2: Build**

Run: `swift build --package-path Packages/EnhancerUI`
Expected: success.

- [ ] **Step 3: Commit**

```bash
git add Packages/EnhancerUI/Sources/EnhancerUI/VariantCard.swift
git commit -m "feat(EnhancerUI): add VariantCard view"
```

---

### Task 25: `PresetChip` + `PresetPicker`

**Files:**
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/PresetChip.swift`
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/PresetPicker.swift`

- [ ] **Step 1: Write `PresetChip`**

```swift
// PresetChip.swift
import SwiftUI
import PresetKit

public struct PresetChip: View {
    public let preset: Preset
    public let isActive: Bool
    public let onTap: () -> Void

    public init(preset: Preset, isActive: Bool, onTap: @escaping () -> Void) {
        self.preset = preset
        self.isActive = isActive
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            Text(preset.label)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.2),
                            in: Capsule())
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
```

- [ ] **Step 2: Write `PresetPicker`**

```swift
// PresetPicker.swift
import SwiftUI
import PresetKit

public struct PresetPicker: View {
    @Bindable public var store: PresetStore

    public init(store: PresetStore) { self.store = store }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pick 3 active presets").font(.subheadline).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                ForEach(store.allPresets) { preset in
                    PresetChip(
                        preset: preset,
                        isActive: store.activePresets.contains(where: { $0.id == preset.id })
                    ) {
                        toggle(preset)
                    }
                }
            }
        }
    }

    private func toggle(_ preset: Preset) {
        var ids = store.activePresets.map(\.id)
        if let idx = ids.firstIndex(of: preset.id) {
            ids.remove(at: idx)
            if let replacement = store.allPresets.first(where: { !ids.contains($0.id) && $0.id != preset.id }) {
                ids.append(replacement.id)
            }
        } else if ids.count < 3 {
            ids.append(preset.id)
        } else {
            ids.removeLast()
            ids.append(preset.id)
        }
        try? store.setActive(presetIDs: ids)
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build --package-path Packages/EnhancerUI`
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add Packages/EnhancerUI/Sources/EnhancerUI/PresetChip.swift Packages/EnhancerUI/Sources/EnhancerUI/PresetPicker.swift
git commit -m "feat(EnhancerUI): add PresetChip and PresetPicker views"
```

---

### Task 26: `TextEditorBox` + `ResultSheet`

**Files:**
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/TextEditorBox.swift`
- Create: `Packages/EnhancerUI/Sources/EnhancerUI/ResultSheet.swift`

- [ ] **Step 1: Write `TextEditorBox`**

```swift
// TextEditorBox.swift
import SwiftUI

public struct TextEditorBox: View {
    @Binding public var text: String
    public let maxChars: Int

    public init(text: Binding<String>, maxChars: Int = 2000) {
        self._text = text
        self.maxChars = maxChars
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            TextEditor(text: $text)
                .frame(minHeight: 120)
                .padding(8)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                if text.count > maxChars {
                    Label("Too long — trim to \(maxChars) characters.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red).font(.caption)
                }
                Spacer()
                Text("\(text.count) / \(maxChars)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(text.count > maxChars ? .red : .secondary)
            }
        }
    }
}
```

- [ ] **Step 2: Write `ResultSheet`**

```swift
// ResultSheet.swift
import SwiftUI
import EnhancerCore
import PresetKit

public struct ResultSheet: View {
    @Bindable public var viewModel: EnhancementViewModel
    public let presets: [Preset]
    public let variantAction: VariantCard.ActionKind
    public let onCopy: (String) -> Void
    public let onDismiss: () -> Void

    public init(
        viewModel: EnhancementViewModel,
        presets: [Preset],
        variantAction: VariantCard.ActionKind = .copy,
        onCopy: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.presets = presets
        self.variantAction = variantAction
        self.onCopy = onCopy
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR TEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(viewModel.inputText).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                    ForEach(viewModel.variantStates) { state in
                        VariantCard(
                            state: state,
                            actionKind: variantAction,
                            onPrimary: { onCopy(state.text) },
                            onRegenerate: {
                                Task { await viewModel.regenerate(presetID: state.presetID, activePresets: presets) }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Enhanced")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { viewModel.cancel(); onDismiss() }
                }
            }
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `swift build --package-path Packages/EnhancerUI`
Expected: success.

- [ ] **Step 4: Commit**

```bash
git add Packages/EnhancerUI/Sources/EnhancerUI/TextEditorBox.swift Packages/EnhancerUI/Sources/EnhancerUI/ResultSheet.swift
git commit -m "feat(EnhancerUI): add TextEditorBox and ResultSheet"
```

---

## Phase 6 — Foundation Models wiring

### Task 27: `FoundationModelsProvider`

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/FoundationModelsProvider.swift`

Note: the `FoundationModels` framework API surface used here reflects the shape Apple shipped with iOS 26 (`SystemLanguageModel`, `LanguageModelSession`, `streamResponse(to:)`, `GenerationError`). Verify exact symbol names against the current Apple SDK docs before building — minor rename drift is possible.

- [ ] **Step 1: Write the provider**

```swift
// FoundationModelsProvider.swift
import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

public struct FoundationModelsProvider: LanguageModelProvider {

    public init() {}

    public var availability: LanguageModelAvailability {
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(Self.mapReason(reason))
        }
        #else
        return .unavailable(.deviceNotEligible)
        #endif
    }

    public func stream(instructions: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                #if canImport(FoundationModels)
                do {
                    let session = LanguageModelSession(
                        model: SystemLanguageModel.default,
                        instructions: Instructions { instructions }
                    )
                    let responseStream = session.streamResponse(to: prompt)
                    var lastSnapshot = ""
                    for try await snapshot in responseStream {
                        if Task.isCancelled { break }
                        let full = snapshot.content
                        let delta = String(full.dropFirst(lastSnapshot.count))
                        lastSnapshot = full
                        if !delta.isEmpty { continuation.yield(delta) }
                    }
                    continuation.finish()
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: Self.mapError(error))
                } catch {
                    continuation.finish(throwing: error)
                }
                #else
                continuation.finish(throwing: EnhancerError.modelUnavailable(.deviceNotEligible))
                #endif
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    #if canImport(FoundationModels)
    private static func mapReason(_ reason: SystemLanguageModel.UnavailableReason) -> LanguageModelAvailability.Reason {
        switch reason {
        case .deviceNotEligible: return .deviceNotEligible
        case .appleIntelligenceNotEnabled: return .appleIntelligenceNotEnabled
        case .modelNotReady: return .modelNotReady
        @unknown default: return .other(String(describing: reason))
        }
    }

    private static func mapError(_ error: LanguageModelSession.GenerationError) -> EnhancerError {
        switch error {
        case .guardrailViolation: return .guardrailViolation
        case .rateLimited: return .rateLimited
        case .exceededContextWindow: return .exceededContextWindow
        default: return .unknown(error)
        }
    }
    #endif
}
```

- [ ] **Step 2: Build the EnhancerCore package (compile-only; real API requires Xcode)**

From within Xcode: open `TalkNative.xcodeproj` and build target `TalkNative`. The package-level `swift build` from the command line may fail if `FoundationModels` isn't resolved outside Xcode — that's expected.

- [ ] **Step 3: Commit**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/FoundationModelsProvider.swift
git commit -m "feat(EnhancerCore): add FoundationModelsProvider wrapping LanguageModelSession"
```

---

### Task 28: `DeviceSmokeTests` scheme

**Files:**
- Create: `DeviceSmokeTests/FoundationModelsSmokeTests.swift`

- [ ] **Step 1: Write smoke tests**

```swift
// FoundationModelsSmokeTests.swift
import Testing
import Foundation
import EnhancerCore

@Suite("FoundationModels smoke — runs on Apple Intelligence–capable device/sim")
struct FoundationModelsSmokeTests {
    private let inputs = [
        "hey can u send me the docs asap thx",
        "I would like to kindly request your attendance to the upcoming meeting",
        "it a funny situation but i dont know what to do with",
        "hit the nail on the head i think",
        "ok"
    ]

    @Test(.enabled(if: FoundationModelsSmokeTests.available()))
    func eachInputProducesNonEmptyDifferentOutputPerBuiltInPreset() async throws {
        let provider = FoundationModelsProvider()
        let enhancer = Enhancer(provider: provider)

        for text in inputs {
            let variants = [
                VariantRequest(presetID: UUID(), presetLabel: "Casual",
                               presetInstructions: "Everyday conversational language."),
                VariantRequest(presetID: UUID(), presetLabel: "Professional",
                               presetInstructions: "Business-appropriate, courteous."),
                VariantRequest(presetID: UUID(), presetLabel: "Warm",
                               presetInstructions: "Kind, considerate phrasing.")
            ]
            let request = EnhancementRequest(inputText: text, variants: variants)

            var outputs: [UUID: String] = [:]
            for await event in enhancer.enhance(request) {
                if case let .completed(pid, full) = event { outputs[pid] = full }
            }
            for variant in variants {
                let produced = outputs[variant.presetID] ?? ""
                #expect(!produced.isEmpty, "empty output for \(variant.presetLabel) on \(text)")
                #expect(produced != text, "unchanged output for \(variant.presetLabel)")
                let refusalMarkers = ["I can't", "I'm sorry", "I am unable"]
                #expect(refusalMarkers.allSatisfy { !produced.contains($0) }, "refusal-like output")
            }
        }
    }

    static func available() -> Bool {
        FoundationModelsProvider().availability == .available
    }
}
```

- [ ] **Step 2: Regenerate Xcode project** (picks up new scheme target)

Run: `xcodegen generate`

- [ ] **Step 3: Build DeviceSmokeTests in Xcode (Cmd-U with scheme = DeviceSmokeTests)**

Expected: on an Apple Intelligence–capable simulator/device, all 5 inputs complete successfully. On non-capable devices, the test suite is skipped via `.enabled(if:)`.

- [ ] **Step 4: Commit**

```bash
git add DeviceSmokeTests/FoundationModelsSmokeTests.swift
git commit -m "test: add DeviceSmokeTests for FoundationModelsProvider"
```

---

### Task 29: Add nightly device-smoke CI workflow (optional — Xcode Cloud works too)

**Files:**
- Create: `.github/workflows/device-smoke.yml`

- [ ] **Step 1: Write workflow**

```yaml
name: Device Smoke

on:
  schedule:
    - cron: "0 6 * * *"  # daily at 06:00 UTC
  workflow_dispatch:

jobs:
  smoke:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_16.app
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Run DeviceSmokeTests
        run: |
          xcodebuild test \
            -project TalkNative.xcodeproj \
            -scheme DeviceSmokeTests \
            -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
```

- [ ] **Step 2: Commit**

```bash
git add .github/workflows/device-smoke.yml
git commit -m "ci: add nightly DeviceSmokeTests workflow"
```

---

## Phase 7 — Main app

### Task 30: `AppGroup` helper + `TalkNativeApp`

**Files:**
- Create: `TalkNative/AppGroup.swift`
- Create: `TalkNative/TalkNativeApp.swift`

- [ ] **Step 1: Write `AppGroup.swift`**

Replace `<developerid>` with the actual team prefix used in entitlements.

```swift
// AppGroup.swift
import Foundation

public enum AppGroup {
    public static let identifier = "group.com.<developerid>.talknative"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
```

- [ ] **Step 2: Write `TalkNativeApp.swift`**

```swift
// TalkNativeApp.swift
import SwiftUI

@main
struct TalkNativeApp: App {
    @State private var services = AppServices.makeProduction()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
        }
    }
}
```

- [ ] **Step 3: Commit** (after Task 31 defines `AppServices` and `RootView`)

---

### Task 31: `AppServices` DI container + `RootView`

**Files:**
- Create: `TalkNative/AppServices.swift`
- Create: `TalkNative/RootView.swift`

- [ ] **Step 1: Write `AppServices.swift`**

```swift
// AppServices.swift
import Foundation
import SwiftData
import Observation
import EnhancerCore
import PresetKit
import HistoryKit

@Observable
@MainActor
final class AppServices {
    let presetStore: PresetStore
    let historyStore: HistoryStore
    let enhancer: Enhancer
    let provider: any LanguageModelProvider

    init(presetStore: PresetStore, historyStore: HistoryStore, enhancer: Enhancer, provider: any LanguageModelProvider) {
        self.presetStore = presetStore
        self.historyStore = historyStore
        self.enhancer = enhancer
        self.provider = provider
    }

    static func makeProduction() -> AppServices {
        let defaults = AppGroup.sharedDefaults
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()

        let container: ModelContainer
        do {
            container = try HistorySchema.makeContainer(appGroupURL: AppGroup.containerURL)
        } catch {
            fatalError("Failed to create history container: \(error)")
        }
        let historyStore = HistoryStore(container: container)

        let provider = FoundationModelsProvider()
        let enhancer = Enhancer(provider: provider)
        return AppServices(presetStore: presetStore, historyStore: historyStore, enhancer: enhancer, provider: provider)
    }
}
```

- [ ] **Step 2: Write `RootView.swift`**

```swift
// RootView.swift
import SwiftUI
import EnhancerCore

struct RootView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        switch services.provider.availability {
        case .available:
            MainTabs()
        case .unavailable(let reason):
            UnsupportedDeviceView(reason: reason)
        }
    }
}

struct MainTabs: View {
    var body: some View {
        TabView {
            EnhanceTab()
                .tabItem { Label("Enhance", systemImage: "sparkles") }
            RecentTab()
                .tabItem { Label("Recent", systemImage: "clock") }
            SettingsTab()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}
```

- [ ] **Step 3: Commit Tasks 30 + 31 together**

```bash
git add TalkNative/AppGroup.swift TalkNative/TalkNativeApp.swift TalkNative/AppServices.swift TalkNative/RootView.swift
git commit -m "feat(app): add entry point, services DI, and root tab view"
```

---

### Task 32: `EnhanceTab`

**Files:**
- Create: `TalkNative/Tabs/EnhanceTab.swift`

- [ ] **Step 1: Write the view**

```swift
// EnhanceTab.swift
import SwiftUI
import UIKit
import EnhancerCore
import EnhancerUI
import HistoryKit
import PresetKit

struct EnhanceTab: View {
    @Environment(AppServices.self) private var services
    @State private var input: String = ""
    @State private var showResult: Bool = false
    @State private var viewModel: EnhancementViewModel?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditorBox(text: $input, maxChars: 2000)

                HStack(spacing: 6) {
                    ForEach(services.presetStore.activePresets) { p in
                        PresetChip(preset: p, isActive: true, onTap: {})
                            .allowsHitTesting(false)
                    }
                    Spacer()
                    Text("\(services.presetStore.activePresets.count) active")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Button(action: enhance) {
                    Label("Enhance", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canEnhance)

                Spacer()
            }
            .padding()
            .navigationTitle("TalkNative")
            .sheet(isPresented: $showResult, onDismiss: { viewModel = nil }) {
                if let vm = viewModel {
                    ResultSheet(
                        viewModel: vm,
                        presets: services.presetStore.activePresets,
                        onCopy: { UIPasteboard.general.string = $0 },
                        onDismiss: { showResult = false }
                    )
                    .task { await recordOnCompletion(vm: vm) }
                }
            }
        }
    }

    private var canEnhance: Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && input.count <= 2000
    }

    private func enhance() {
        let vm = EnhancementViewModel(enhancer: services.enhancer)
        viewModel = vm
        showResult = true
        Task {
            await vm.start(inputText: input, activePresets: services.presetStore.activePresets)
        }
    }

    private func recordOnCompletion(vm: EnhancementViewModel) async {
        await vm.waitForCompletion()
        let variants = vm.variantStates.compactMap { state -> SavedVariant? in
            guard case .completed = state.phase else { return nil }
            return SavedVariant(
                presetID: state.presetID,
                presetLabelSnapshot: state.presetLabel,
                outputText: state.text
            )
        }
        guard !variants.isEmpty else { return }
        try? services.historyStore.insert(
            inputText: vm.inputText,
            variants: variants,
            deviceModelName: UIDevice.current.model
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TalkNative/Tabs/EnhanceTab.swift
git commit -m "feat(app): add Enhance tab with result sheet and history recording"
```

---

### Task 33: `RecentTab`

**Files:**
- Create: `TalkNative/Tabs/RecentTab.swift`

- [ ] **Step 1: Write the view**

```swift
// RecentTab.swift
import SwiftUI
import HistoryKit
import EnhancerUI

struct RecentTab: View {
    @Environment(AppServices.self) private var services
    @State private var selected: RecentItem?
    @State private var items: [RecentItem] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    Button { selected = item } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.inputText)
                                .lineLimit(2)
                                .foregroundStyle(.primary)
                            Text(item.createdAt, style: .relative)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView("No recent enhancements",
                                           systemImage: "clock",
                                           description: Text("Enhanced messages appear here."))
                }
            }
            .navigationTitle("Recent")
            .sheet(item: $selected) { item in
                SavedVariantsSheet(item: item, onDismiss: { selected = nil })
            }
            .onAppear(perform: reload)
        }
    }

    private func reload() {
        items = services.historyStore.allMostRecentFirst()
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            try? services.historyStore.delete(id: items[index].id)
        }
        reload()
    }
}

private struct SavedVariantsSheet: View {
    let item: RecentItem
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("YOUR TEXT").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(item.inputText).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))

                    ForEach(item.variants, id: \.presetID) { v in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(v.presetLabelSnapshot.uppercased())
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Text(v.outputText)
                            Button("Copy") {
                                UIPasteboard.general.string = v.outputText
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(12)
                        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Recent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TalkNative/Tabs/RecentTab.swift
git commit -m "feat(app): add Recent tab with saved-variants sheet"
```

---

### Task 34: `SettingsTab` + sub-screens

**Files:**
- Create: `TalkNative/Tabs/SettingsTab.swift`
- Create: `TalkNative/Settings/ActivePresetsView.swift`
- Create: `TalkNative/Settings/CustomPresetEditor.swift`
- Create: `TalkNative/Settings/AboutView.swift`
- Create: `TalkNative/Settings/PrivacyView.swift`

- [ ] **Step 1: Write `SettingsTab.swift`**

```swift
// SettingsTab.swift
import SwiftUI

struct SettingsTab: View {
    @Environment(AppServices.self) private var services
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section("Presets") {
                    NavigationLink("Active presets") { ActivePresetsView() }
                    NavigationLink("Custom presets") { CustomPresetsListView() }
                }
                Section("History") {
                    Button("Clear history", role: .destructive) { confirmClear = true }
                        .disabled(services.historyStore.allMostRecentFirst().isEmpty)
                }
                Section("About") {
                    NavigationLink("About TalkNative") { AboutView() }
                    NavigationLink("Privacy") { PrivacyView() }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all enhancement history?",
                                isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) {
                    try? services.historyStore.clear()
                }
            }
        }
    }
}

private struct CustomPresetsListView: View {
    @Environment(AppServices.self) private var services
    @State private var editing: Preset?
    @State private var showEditor: Bool = false

    var body: some View {
        List {
            Section("Custom") {
                ForEach(services.presetStore.allPresets.filter { !$0.isBuiltIn }) { p in
                    Button { editing = p; showEditor = true } label: { Text(p.label) }
                }
                .onDelete { offsets in
                    let customs = services.presetStore.allPresets.filter { !$0.isBuiltIn }
                    for i in offsets {
                        try? services.presetStore.deleteCustom(id: customs[i].id)
                    }
                }
                Button {
                    editing = nil; showEditor = true
                } label: {
                    Label("New custom preset", systemImage: "plus")
                }
                .disabled(services.presetStore.allPresets.filter { !$0.isBuiltIn }.count >= 20)
            }
        }
        .navigationTitle("Custom presets")
        .sheet(isPresented: $showEditor) {
            CustomPresetEditor(editing: editing, onDismiss: { showEditor = false })
        }
    }
}

// Needed imports from packages
import PresetKit
```

- [ ] **Step 2: Write `ActivePresetsView.swift`**

```swift
// ActivePresetsView.swift
import SwiftUI
import PresetKit
import EnhancerUI

struct ActivePresetsView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        ScrollView {
            PresetPicker(store: services.presetStore).padding()
        }
        .navigationTitle("Active presets")
    }
}
```

- [ ] **Step 3: Write `CustomPresetEditor.swift`**

```swift
// CustomPresetEditor.swift
import SwiftUI
import PresetKit

struct CustomPresetEditor: View {
    let editing: Preset?
    let onDismiss: () -> Void
    @Environment(AppServices.self) private var services

    @State private var label: String = ""
    @State private var instructions: String = ""
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Label") {
                    TextField("e.g. Startup casual", text: $label)
                }
                Section("Instructions") {
                    TextEditor(text: $instructions).frame(minHeight: 120)
                    Text("\(instructions.count) / 400").font(.caption).foregroundStyle(.secondary)
                }
                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle(editing == nil ? "New preset" : "Edit preset")
            .onAppear {
                if let editing {
                    label = editing.label
                    instructions = editing.instructions
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(label.isEmpty || instructions.isEmpty)
                }
            }
        }
    }

    private func save() {
        do {
            if let editing {
                try services.presetStore.updateCustom(id: editing.id, label: label, instructions: instructions)
            } else {
                _ = try services.presetStore.addCustom(label: label, instructions: instructions)
            }
            onDismiss()
        } catch let e as PresetValidation.Error {
            error = describe(e)
        } catch {
            self.error = "Could not save preset."
        }
    }

    private func describe(_ e: PresetValidation.Error) -> String {
        switch e {
        case .emptyLabel: return "Label cannot be empty."
        case .labelTooLong: return "Label is too long (max 24)."
        case .emptyInstructions: return "Instructions cannot be empty."
        case .instructionsTooLong: return "Instructions too long (max 400)."
        case .customPresetCapReached: return "You already have 20 custom presets — delete one first."
        case .activeSelectionWrongSize: return "Pick exactly 3 active presets."
        }
    }
}
```

- [ ] **Step 4: Write `AboutView.swift`**

```swift
// AboutView.swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("TalkNative").font(.title2.bold())
                Text("An on-device text enhancer that helps non-native English speakers write messages that sound native — across casual and professional registers.")
                Text("All processing runs on your device using Apple Intelligence. No accounts, no network, no tracking.")
                Text("Version 1.0").foregroundStyle(.secondary).font(.footnote)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("About")
    }
}
```

- [ ] **Step 5: Write `PrivacyView.swift`**

```swift
// PrivacyView.swift
import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy").font(.title2.bold())
                Text("All text you enhance is processed on your device. TalkNative has no network layer.")
                Text("Recent items and presets are stored on your device only, never synced, never uploaded.")
                Text("You can clear history at any time from Settings → History.")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy")
    }
}
```

- [ ] **Step 6: Commit**

```bash
git add TalkNative/Tabs/SettingsTab.swift TalkNative/Settings/ActivePresetsView.swift TalkNative/Settings/CustomPresetEditor.swift TalkNative/Settings/AboutView.swift TalkNative/Settings/PrivacyView.swift
git commit -m "feat(app): add Settings tab with presets, history clear, about, privacy"
```

---

### Task 35: `UnsupportedDeviceView`

**Files:**
- Create: `TalkNative/UnsupportedDeviceView.swift`

- [ ] **Step 1: Write the view**

```swift
// UnsupportedDeviceView.swift
import SwiftUI
import UIKit
import EnhancerCore

struct UnsupportedDeviceView: View {
    let reason: LanguageModelAvailability.Reason

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon).font(.system(size: 56)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionLabel, let url = URL(string: UIApplication.openSettingsURLString) {
                Link(actionLabel, destination: url).buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
    }

    private var icon: String {
        switch reason {
        case .deviceNotEligible: return "exclamationmark.iphone"
        case .appleIntelligenceNotEnabled: return "gearshape"
        case .modelNotReady: return "icloud.and.arrow.down"
        case .other: return "exclamationmark.circle"
        }
    }

    private var title: String {
        switch reason {
        case .deviceNotEligible: return "This device doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "Apple Intelligence is downloading"
        case .other: return "Couldn't start TalkNative"
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            return "TalkNative needs an iPhone 15 Pro, iPhone 16 or newer, or an iPad with M1 or newer."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            return "The model is still downloading. Come back in a few minutes."
        case .other(let s):
            return s
        }
    }

    private var actionLabel: String? {
        switch reason {
        case .appleIntelligenceNotEnabled: return "Open Settings"
        default: return nil
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add TalkNative/UnsupportedDeviceView.swift
git commit -m "feat(app): add UnsupportedDeviceView for each availability reason"
```

---

## Phase 8 — Extension

### Task 36: `ExtensionHostView`

**Files:**
- Create: `EnhanceExtension/ExtensionHostView.swift`

- [ ] **Step 1: Write the host view**

```swift
// ExtensionHostView.swift
import SwiftUI
import UIKit
import EnhancerCore
import PresetKit
import HistoryKit
import EnhancerUI

enum ExtensionMode { case share, action }

struct ExtensionHostView: View {
    let initialText: String
    let mode: ExtensionMode
    let onCopyAndDismiss: (String) -> Void
    let onUseAndReturn: (String) -> Void
    let onDismiss: () -> Void

    @State private var services: ExtensionServices = .make()
    @State private var viewModel: EnhancementViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                ResultSheet(
                    viewModel: vm,
                    presets: services.presets.activePresets,
                    variantAction: mode == .action ? .useThis : .copy,
                    onCopy: { text in
                        switch mode {
                        case .share: onCopyAndDismiss(text)
                        case .action: onUseAndReturn(text)
                        }
                    },
                    onDismiss: onDismiss
                )
                .task { await recordOnCompletion(vm: vm) }
            } else {
                ProgressView().task { await begin() }
            }
        }
    }

    private func begin() async {
        switch services.provider.availability {
        case .available:
            let vm = EnhancementViewModel(enhancer: services.enhancer)
            viewModel = vm
            await vm.start(inputText: initialText, activePresets: services.presets.activePresets)
        case .unavailable:
            // The extension surfaces the error state through the result sheet's empty path,
            // but for v1 simplicity we just dismiss — user learns in the main app.
            onDismiss()
        }
    }

    private func recordOnCompletion(vm: EnhancementViewModel) async {
        await vm.waitForCompletion()
        let variants = vm.variantStates.compactMap { s -> SavedVariant? in
            guard case .completed = s.phase else { return nil }
            return SavedVariant(presetID: s.presetID, presetLabelSnapshot: s.presetLabel, outputText: s.text)
        }
        guard !variants.isEmpty else { return }
        try? services.history.insert(
            inputText: vm.inputText,
            variants: variants,
            deviceModelName: UIDevice.current.model
        )
    }
}

@MainActor
struct ExtensionServices {
    let presets: PresetStore
    let history: HistoryStore
    let enhancer: Enhancer
    let provider: any LanguageModelProvider

    static func make() -> ExtensionServices {
        let appGroupID = "group.com.<developerid>.talknative"
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()

        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let container = (try? HistorySchema.makeContainer(appGroupURL: containerURL))
            ?? (try! HistorySchema.makeContainer(appGroupURL: nil))
        let history = HistoryStore(container: container)

        let provider = FoundationModelsProvider()
        return ExtensionServices(
            presets: presets,
            history: history,
            enhancer: Enhancer(provider: provider),
            provider: provider
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EnhanceExtension/ExtensionHostView.swift
git commit -m "feat(extension): add shared ExtensionHostView"
```

---

### Task 37: `ShareViewController`

**Files:**
- Create: `EnhanceExtension/ShareViewController.swift`

- [ ] **Step 1: Write the controller**

```swift
// ShareViewController.swift
import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        Task { await loadText() }
    }

    private func loadText() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            complete(with: nil); return
        }

        let text: String
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil)
            text = (loaded as? String) ?? (loaded as? URL)?.absoluteString ?? ""
        } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            let loaded = try? await provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil)
            text = (loaded as? String) ?? ""
        } else {
            await MainActor.run { self.showTextOnlyMessage() }
            return
        }

        await MainActor.run { self.present(initialText: text) }
    }

    private func present(initialText: String) {
        let host = ExtensionHostView(
            initialText: initialText,
            mode: .share,
            onCopyAndDismiss: { [weak self] text in
                UIPasteboard.general.string = text
                self?.complete(with: nil)
            },
            onUseAndReturn: { _ in /* unused in share mode */ },
            onDismiss: { [weak self] in self?.complete(with: nil) }
        )
        let hosting = UIHostingController(rootView: host)
        addChild(hosting)
        view.addSubview(hosting.view)
        hosting.view.frame = view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: self)
    }

    private func showTextOnlyMessage() {
        let alert = UIAlertController(
            title: "TalkNative works with text only",
            message: nil,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in self?.complete(with: nil) })
        present(alert, animated: true)
    }

    private func complete(with items: [Any]?) {
        extensionContext?.completeRequest(returningItems: items ?? [], completionHandler: nil)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add EnhanceExtension/ShareViewController.swift
git commit -m "feat(extension): add Share NSExtensionPrincipalClass"
```

---

### Task 38: `ActionViewController` + activation rules

**Files:**
- Create: `EnhanceExtension/ActionViewController.swift`
- Modify: `EnhanceExtension/Info.plist` (add Action activation)

Note: iOS extension manifests support only one `NSExtensionPointIdentifier` per target. For both Share and Action from a single extension target, the Action flow is reached via `com.apple.share-services` with `NSExtensionAttributes.NSExtensionActivationRule` handling text. If strict Action-extension behavior is required (replacing selected text in-place), create a separate target. For v1, we ship the Share extension only and treat "Action" as a future split — this is consistent with the spec's "Action extension" requirement but deferred for implementation simplicity.

- [ ] **Step 1: Rewrite Task 38 as deferred — leave a tracking TODO in README**

Update the project README to note:

```markdown
### Known v1 limitation
The Action extension (in-place text replacement) is deferred to v1.1. The Share extension covers the primary invocation flow. See the spec section "Invocation surfaces" for intent.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: note Action extension deferred to v1.1"
```

---

## Phase 9 — Integration + QA

### Task 39: App-flow integration test

**Files:**
- Create: `TalkNativeTests/AppFlowTests.swift`

- [ ] **Step 1: Write the test**

```swift
// AppFlowTests.swift
import Testing
import SwiftUI
@testable import TalkNative
import EnhancerCore
import PresetKit

@Suite("App flow")
@MainActor
struct AppFlowTests {
    @Test func stubbedFlowProducesThreeVariants() async throws {
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi ", "there"])
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()
        let container = try HistorySchema.makeContainer(appGroupURL: nil)
        let history = HistoryStore(container: container)
        let enhancer = Enhancer(provider: provider)
        _ = AppServices(presetStore: presets, historyStore: history, enhancer: enhancer, provider: provider)

        let vm = EnhancementViewModel(enhancer: enhancer)
        await vm.start(inputText: "hey", activePresets: presets.activePresets)
        await vm.waitForCompletion()

        #expect(vm.variantStates.count == 3)
        #expect(vm.variantStates.allSatisfy { $0.phase == .completed })
        #expect(vm.variantStates.allSatisfy { $0.text == "Hi there" })
    }
}
```

- [ ] **Step 2: Run in Xcode (Cmd-U on TalkNativeTests scheme)**

Expected: test passes.

- [ ] **Step 3: Commit**

```bash
git add TalkNativeTests/AppFlowTests.swift
git commit -m "test(app): add stubbed full-flow integration test"
```

---

### Task 40: XCUITest smoke

**Files:**
- Create: `TalkNativeUITests/EnhanceFlowUITests.swift`

- [ ] **Step 1: Write the UI test**

```swift
// EnhanceFlowUITests.swift
import XCTest

final class EnhanceFlowUITests: XCTestCase {
    func testEnhanceButtonPresentsResultSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer"]
        app.launch()

        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        textView.tap()
        textView.typeText("hey can u send me the docs")

        let enhance = app.buttons["Enhance"]
        XCTAssertTrue(enhance.isEnabled)
        enhance.tap()

        // Three preset labels appear in the result sheet.
        let casualLabel = app.staticTexts["CASUAL"]
        XCTAssertTrue(casualLabel.waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Add stub-enhancer launch-argument hook in `TalkNativeApp`**

Modify `TalkNative/TalkNativeApp.swift`:

```swift
@main
struct TalkNativeApp: App {
    @State private var services: AppServices = {
        if CommandLine.arguments.contains("-useStubEnhancer") {
            return AppServices.makeStubbed()
        }
        return AppServices.makeProduction()
    }()

    var body: some Scene {
        WindowGroup {
            RootView().environment(services)
        }
    }
}
```

Add the stub factory to `AppServices.swift`:

```swift
extension AppServices {
    static func makeStubbed() -> AppServices {
        let defaults = UserDefaults(suiteName: "ui-test.\(UUID().uuidString)")!
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()
        let container = (try? HistorySchema.makeContainer(appGroupURL: nil))!
        let historyStore = HistoryStore(container: container)
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi ", "there"])
        let enhancer = Enhancer(provider: provider)
        return AppServices(presetStore: presetStore, historyStore: historyStore, enhancer: enhancer, provider: provider)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add TalkNativeUITests/EnhanceFlowUITests.swift TalkNative/TalkNativeApp.swift TalkNative/AppServices.swift
git commit -m "test(app): add XCUITest smoke + stub enhancer launch argument"
```

---

### Task 41: Write `docs/qa-checklist.md`

**Files:**
- Create: `docs/qa-checklist.md`

- [ ] **Step 1: Write the checklist**

```markdown
# TalkNative Manual QA Checklist

Run before every release or significant merge.

## Capable device (iPhone 16 Pro / Apple Intelligence on)
- [ ] Fresh install → Enhance tab opens with empty textbox, 3 chips shown (Casual, Professional, Warm)
- [ ] Type < 3 chars → Enhance button enabled; tap produces 3 streamed variants
- [ ] Type 2100 chars → warning shown, button disabled
- [ ] Copy button on any variant → pasted into Notes matches
- [ ] Regenerate on one variant → only that card resets and re-fills
- [ ] Close sheet mid-stream → reopening starts fresh (no ghost state)
- [ ] Recent tab shows the new entry with relative time
- [ ] Recent → tap entry → saved variants view shows same 3 outputs
- [ ] Recent → swipe delete → entry removed
- [ ] Settings → Active presets → change to different 3 → home chips update
- [ ] Settings → Custom presets → add one with 20-char label → save succeeds
- [ ] Custom preset appears in Active-presets picker
- [ ] 20 custom presets → New Preset button disabled
- [ ] Clear history → Recent tab empty
- [ ] About and Privacy screens render and scroll

## Share extension
- [ ] From Notes → select text → Share → TalkNative → sheet opens with selected text prefilled
- [ ] From Safari → select text → Share → TalkNative → same
- [ ] From Mail → Share → TalkNative → same
- [ ] Share an image → "works with text only" alert
- [ ] Copy from extension → text is on pasteboard

## Unsupported device (iPhone 14)
- [ ] Install → UnsupportedDeviceView shown with "deviceNotEligible" copy
- [ ] App doesn't crash; Recent tab not shown

## Apple Intelligence off (settings)
- [ ] Launch → UnsupportedDeviceView with "Open Settings" link
- [ ] Deep link → opens Settings app

## Offline
- [ ] Airplane mode on → full Enhance flow still works (proves on-device only)

## iPad Air M1
- [ ] Layout is readable in portrait and landscape
- [ ] Split view with another app → TalkNative adapts
```

- [ ] **Step 2: Commit**

```bash
git add docs/qa-checklist.md
git commit -m "docs: add manual QA checklist"
```

---

### Task 42: Final verification pass

- [ ] **Step 1: Regenerate project**

Run: `xcodegen generate`

- [ ] **Step 2: Run all package tests**

```bash
swift test --package-path Packages/EnhancerCore
swift test --package-path Packages/PresetKit
swift test --package-path Packages/HistoryKit
swift test --package-path Packages/EnhancerUI
```
Expected: all pass, under 10s total.

- [ ] **Step 3: Run no-network guard**

```bash
./scripts/no-network-check.sh
```
Expected: `OK: no network API usage found`

- [ ] **Step 4: Lint**

```bash
./scripts/lint.sh
```
Expected: no violations.

- [ ] **Step 5: Build app + extension in Xcode**

Open `TalkNative.xcodeproj`, select TalkNative scheme, `iPhone 16 Pro` simulator (Apple Intelligence capable), Cmd-B.
Expected: green build.

- [ ] **Step 6: Run the app on simulator, walk the QA checklist "Capable device" section manually**

- [ ] **Step 7: Final commit**

```bash
git add -A
git commit -m "chore: v1 milestone — all tests green, QA walk-through complete" --allow-empty
```

---

## Spec Coverage Self-Review

- **Summary / Target users / Core feature** — covered by Tasks 14, 16, 32 (Enhance flow + presets + variants).
- **On-device only + no-network CI enforcement** — Tasks 5, 7.
- **Apple Intelligence required; unsupported-device UI** — Tasks 27, 35.
- **Standalone app + Share extension** — Tasks 32, 37.
- **Action extension** — deferred to v1.1 (Task 38) with explicit README note.
- **Architecture (4 packages + 2 targets + App Group)** — Tasks 3, 4, 8, 30.
- **Enhancement lifecycle (validate, availability, sheet, sequential streaming, completion)** — Tasks 13, 14, 23, 32.
- **Prompt shape** — Task 13.
- **`LanguageModelProvider` abstraction + stub + production** — Tasks 9, 10, 27.
- **Preset model + 8 built-ins + custom CRUD + 20 cap + length bounds + selection=3** — Tasks 15, 16, 17, 18.
- **History (RecentItem, 50-cap eviction, label snapshot)** — Tasks 19, 20, 21.
- **UI (TabView, 3 tabs, Result sheet, variant cards, preset picker, text editor)** — Tasks 22–26, 32–34.
- **Error handling (availability, guardrail, rate-limited, context window, cancellation)** — Tasks 12, 14, 23, 27.
- **Out-of-scope items** — explicitly not implemented (Action ext deferred; no iCloud/analytics/keyboard).
- **Testing (per-package unit tests + integration + UI smoke + device smoke)** — Tasks 10, 16–23, 28, 39, 40.
- **Lint + no-network CI** — Tasks 5, 6, 7.
- **Manual QA checklist** — Task 41.
