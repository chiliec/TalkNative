# Keyboard Extension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a TalkNative custom keyboard extension that rewrites selected or just-typed text in place inside any iOS app, with a one-tap undo.

**Architecture:** Two new SPM packages — `TextReplacement` (leaf, no deps, holds the proxy protocol and all replace/undo arithmetic) and `KeyboardUI` (panel state machine and keyboard-density SwiftUI views) — consumed by a thin `TalkNativeKeyboard` app-extension target that owns only `UIInputViewController`, the `UITextDocumentProxy` adapter, and a services factory. `Enhancer`, `LanguageModelProvider`, `PresetStore`, `HistoryStore`, and `EnhancementViewModel` are used unchanged.

**Tech Stack:** Swift 6 (tools 6.2), SwiftUI, Swift Concurrency, `@Observable`, UIKit (`UIInputViewController` only), Swift Testing (`import Testing`, `@Suite`, `@Test`, `#expect`), XCTest for UI tests, XcodeGen, swift-format, GitHub Actions.

**Source spec:** `docs/superpowers/specs/2026-08-01-keyboard-extension-design.md`

## Global Constraints

- Swift tools version `6.2`; every new `Package.swift` declares `platforms: [.iOS(.v26), .macOS(.v26)]`.
- `TextReplacement` has **zero** dependencies and imports **only** `Foundation`. No UIKit, no SwiftUI.
- `KeyboardUI` imports SwiftUI but **never** UIKit — it must compile and test on macOS.
- Zero network APIs anywhere. `scripts/no-network-check.sh` forbids `URLSession|\bNetwork\b|NWConnection|URLRequest|URLProtocol`.
- Tests use Swift Testing (`import Testing`), matching every existing package. Not XCTest.
- App Group identifier is exactly `group.com.axveer.talknative`.
- Bundle identifier for the new target is exactly `com.axveer.talknative.keyboard`.
- Never edit `TalkNative.xcodeproj`. Edit `project.yml` and run `xcodegen generate`.
- Delete counts are always **grapheme-cluster** counts (`String.count`), never `utf16.count`.
- Commit messages carry no `Co-Authored-By` trailer.
- `maxChars` is 2000 everywhere, matching `TextEditorBox(maxChars: 2000)` at `TalkNative/Tabs/EnhanceTab.swift:21`.

---

## Task order and dependencies

```
Task 1  (spike)  ──gate──▶ everything below
Task 2 ─▶ Task 3 ─▶ Task 4 ─▶ Task 5        (TextReplacement)
                        └─▶ Task 6 ─▶ Task 7 ─▶ Task 8   (KeyboardUI)
                                          └─▶ Task 9 ─▶ Task 10 ─▶ Task 11  (target)
                                                              └─▶ Task 12 ─▶ Task 13 ─▶ Task 14
```

**Task 1 is a hard gate.** If it fails, stop and report — the feature is not viable.

---

## File structure

### New files

**`Packages/TextReplacement/`** *(new SPM package, leaf)*
- `Package.swift`
- `Sources/TextReplacement/TextDocumentProxying.swift` — the protocol
- `Sources/TextReplacement/CapturedText.swift` — `CapturedText`, `CaptureOutcome`
- `Sources/TextReplacement/TextCapture.swift` — capture policy
- `Sources/TextReplacement/ReplacementPlan.swift` — plan construction
- `Sources/TextReplacement/TextReplacer.swift` — plan application
- `Sources/TextReplacement/StubTextDocumentProxy.swift` — in-memory field model
- `Tests/TextReplacementTests/StubTextDocumentProxyTests.swift`
- `Tests/TextReplacementTests/TextCaptureTests.swift`
- `Tests/TextReplacementTests/ReplacementPlanTests.swift`
- `Tests/TextReplacementTests/RoundTripTests.swift`
- `Tests/TextReplacementTests/UnicodeCorpus.swift` — shared fixture

**`Packages/KeyboardUI/`** *(new SPM package)*
- `Package.swift`
- `Sources/KeyboardUI/KeyboardPanelState.swift`
- `Sources/KeyboardUI/KeyboardPanelViewModel.swift`
- `Sources/KeyboardUI/CompactVariantRow.swift`
- `Sources/KeyboardUI/CapturedTextStrip.swift`
- `Sources/KeyboardUI/FullAccessPromptRow.swift`
- `Sources/KeyboardUI/KeyboardPanel.swift`
- `Tests/KeyboardUITests/KeyboardPanelViewModelTests.swift`

**`TalkNativeKeyboard/`** *(new app-extension target)*
- `Info.plist`
- `TalkNativeKeyboard.entitlements`
- `KeyboardInputViewController.swift`
- `LiveTextDocumentProxy.swift`
- `KeyboardServices.swift`

### Modified files

- `project.yml` — two package entries, new target, app dependency
- `scripts/no-network-check.sh:5` — add `TalkNativeKeyboard` to `TARGETS`
- `scripts/lint.sh:10` — add `TalkNativeKeyboard` to the lint arguments
- `.github/workflows/ci.yml` — two new `swift test` steps
- `TalkNative/LaunchArguments.swift` — add `-showKeyboardPanel`
- `TalkNative/RootView.swift` — honour the new launch argument
- `TalkNativeUITests/KeyboardPanelUITests.swift` *(new)*
- `docs/superpowers/specs/2026-04-18-talknative-design.md` — correct lines 29 and 72
- `README.md:68` — replace the deferred-Action-extension note
- `CLAUDE.md` — add the new target and packages to the architecture section

---

## Phase 0 — Viability gate

### Task 1: Spike — Foundation Models inside a keyboard extension

**Files:**
- Create (throwaway, deleted at end of task): `SpikeKeyboard/` and a temporary `project.yml` target

**Interfaces:**
- Consumes: nothing
- Produces: a go/no-go decision only. No code survives this task.

This task exists because the entire feature rests on one unverified assumption: that a keyboard extension's memory budget can accommodate a `FoundationModelsProvider` call. Foundation Models runs out-of-process in a system daemon, so the weights should not count against the extension — but "should" is not "does", and finding out now costs an afternoon instead of two weeks.

- [ ] **Step 1: Add a throwaway keyboard target to `project.yml`**

Append to the `targets:` map:

```yaml
  SpikeKeyboard:
    type: app-extension
    platform: iOS
    deploymentTarget: "26.0"
    sources: [SpikeKeyboard]
    info:
      path: SpikeKeyboard/Info.plist
      properties:
        CFBundleDisplayName: Spike
        NSExtension:
          NSExtensionPointIdentifier: com.apple.keyboard-service
          NSExtensionPrincipalClass: $(PRODUCT_MODULE_NAME).SpikeInputViewController
          NSExtensionAttributes:
            IsASCIICapable: false
            PrefersRightToLeft: false
            PrimaryLanguage: en-US
            RequestsOpenAccess: false
    dependencies:
      - package: EnhancerCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.axveer.talknative.spikekeyboard
```

Add `- target: SpikeKeyboard` with `embed: true` to the `TalkNative` target's `dependencies:` list.

- [ ] **Step 2: Create `SpikeKeyboard/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

XcodeGen merges the `info.properties` from `project.yml` into this file at generation time.

- [ ] **Step 3: Create `SpikeKeyboard/SpikeInputViewController.swift`**

```swift
import UIKit
import EnhancerCore

final class SpikeInputViewController: UIInputViewController {
    private let label = UILabel()
    private var runs = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        let height = view.heightAnchor.constraint(equalToConstant: 240)
        height.priority = .required - 1
        height.isActive = true

        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 13)
        label.text = "starting…"
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            label.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
        ])

        Task { await runSpike() }
    }

    private func runSpike() async {
        let provider = FoundationModelsProvider()
        guard case .available = provider.availability else {
            label.text = "unavailable: \(provider.availability)"
            return
        }
        for i in 1...3 {
            var output = ""
            do {
                let stream = provider.stream(
                    instructions: "Rewrite the user's text to sound natural and fluent.",
                    prompt: "i has went to the store yesterday and buyed some milks"
                )
                for try await chunk in stream { output += chunk }
            } catch {
                label.text = "run \(i) failed: \(error)"
                return
            }
            runs = i
            label.text = "run \(i)/3 ok (\(output.count) chars)\n\(output.prefix(120))"
        }
        label.text = "SPIKE PASS — 3/3 runs completed"
    }
}
```

- [ ] **Step 4: Generate and build**

```bash
xcodegen generate
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Run on a physical device**

This step **cannot** be done in the simulator — Foundation Models availability and extension memory limits are only meaningful on real hardware.

1. Run the `TalkNative` scheme on a physical Apple Intelligence-capable device from Xcode.
2. Settings → General → Keyboard → Keyboards → Add New Keyboard → Spike.
3. Open Notes, tap the text area, long-press the globe key, pick Spike.
4. Watch the Xcode console for jetsam / `EXC_RESOURCE` messages.

Expected: the label reads `SPIKE PASS — 3/3 runs completed` and the keyboard is not terminated.

- [ ] **Step 6: Record the result and decide**

**If the spike passes:** proceed to Task 2.

**If the keyboard is jetsammed or the model is unreachable:** STOP. Do not continue with any remaining task. Report the exact failure (console output, memory footprint from the Xcode Debug navigator) and add a "Spike outcome" section to the spec at `docs/superpowers/specs/2026-08-01-keyboard-extension-design.md` recording it. The feature is not viable in this form.

- [ ] **Step 7: Remove the spike**

```bash
rm -rf SpikeKeyboard
```

Revert the `SpikeKeyboard` target block and the `- target: SpikeKeyboard` app dependency from `project.yml`, then:

```bash
xcodegen generate
```

- [ ] **Step 8: Commit the decision**

```bash
git add docs/superpowers/specs/2026-08-01-keyboard-extension-design.md
git commit -m "docs: record keyboard extension memory spike result"
```

---

## Phase 1 — TextReplacement package

### Task 2: Scaffold TextReplacement with the proxy protocol and stub

**Files:**
- Create: `Packages/TextReplacement/Package.swift`
- Create: `Packages/TextReplacement/Sources/TextReplacement/TextDocumentProxying.swift`
- Create: `Packages/TextReplacement/Sources/TextReplacement/StubTextDocumentProxy.swift`
- Test: `Packages/TextReplacement/Tests/TextReplacementTests/StubTextDocumentProxyTests.swift`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `protocol TextDocumentProxying: AnyObject` with `var selectedText: String? { get }`, `var documentContextBeforeInput: String? { get }`, `var documentContextAfterInput: String? { get }`, `func insertText(_ text: String)`, `func deleteBackward()`
  - `final class StubTextDocumentProxy: TextDocumentProxying` with `init(before: String = "", selected: String = "", after: String = "")` and `var document: String { get }`

- [ ] **Step 1: Create the package manifest**

`Packages/TextReplacement/Package.swift`:

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "TextReplacement",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "TextReplacement", targets: ["TextReplacement"])],
    targets: [
        .target(name: "TextReplacement"),
        .testTarget(name: "TextReplacementTests", dependencies: ["TextReplacement"]),
    ]
)
```

- [ ] **Step 2: Write the failing test**

`Packages/TextReplacement/Tests/TextReplacementTests/StubTextDocumentProxyTests.swift`:

```swift
import Testing
@testable import TextReplacement

@Suite("StubTextDocumentProxy")
struct StubTextDocumentProxyTests {
    @Test func reportsSelectionAndContext() {
        let proxy = StubTextDocumentProxy(before: "Hello ", selected: "world", after: "!")
        #expect(proxy.selectedText == "world")
        #expect(proxy.documentContextBeforeInput == "Hello ")
        #expect(proxy.documentContextAfterInput == "!")
        #expect(proxy.document == "Hello world!")
    }

    @Test func emptyFieldsReportNil() {
        let proxy = StubTextDocumentProxy()
        #expect(proxy.selectedText == nil)
        #expect(proxy.documentContextBeforeInput == nil)
        #expect(proxy.documentContextAfterInput == nil)
    }

    @Test func deleteBackwardClearsEntireSelectionInOneCall() {
        let proxy = StubTextDocumentProxy(before: "a", selected: "bcdef", after: "g")
        proxy.deleteBackward()
        #expect(proxy.document == "ag")
        #expect(proxy.selectedText == nil)
    }

    @Test func deleteBackwardRemovesOneGraphemeClusterWhenNoSelection() {
        let proxy = StubTextDocumentProxy(before: "ab\u{1F1FA}\u{1F1E6}", after: "")
        proxy.deleteBackward()
        #expect(proxy.document == "ab")
    }

    @Test func insertTextReplacesSelection() {
        let proxy = StubTextDocumentProxy(before: "Hi ", selected: "there", after: "!")
        proxy.insertText("everyone")
        #expect(proxy.document == "Hi everyone!")
        #expect(proxy.selectedText == nil)
    }

    @Test func deleteBackwardOnEmptyDocumentIsSafe() {
        let proxy = StubTextDocumentProxy()
        proxy.deleteBackward()
        #expect(proxy.document == "")
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --package-path Packages/TextReplacement`

Expected: compile failure — `cannot find 'StubTextDocumentProxy' in scope`.

- [ ] **Step 4: Write the protocol**

`Packages/TextReplacement/Sources/TextReplacement/TextDocumentProxying.swift`:

```swift
import Foundation

/// The subset of `UITextDocumentProxy` this package needs.
///
/// Declared here so capture and replacement logic can be unit-tested on macOS
/// without UIKit. `LiveTextDocumentProxy` in the keyboard target forwards to
/// the real `UITextDocumentProxy`.
public protocol TextDocumentProxying: AnyObject {
    var selectedText: String? { get }
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
}
```

- [ ] **Step 5: Write the stub**

`Packages/TextReplacement/Sources/TextReplacement/StubTextDocumentProxy.swift`:

```swift
import Foundation

/// An in-memory model of a text field, for tests.
///
/// Tests assert on `document` — the final state of the user's text — rather
/// than on call sequences. Whether we called the right methods matters less
/// than whether the user's text is correct afterwards.
public final class StubTextDocumentProxy: TextDocumentProxying {
    public var before: String
    public var selected: String
    public var after: String

    public init(before: String = "", selected: String = "", after: String = "") {
        self.before = before
        self.selected = selected
        self.after = after
    }

    public var document: String { before + selected + after }

    public var selectedText: String? { selected.isEmpty ? nil : selected }
    public var documentContextBeforeInput: String? { before.isEmpty ? nil : before }
    public var documentContextAfterInput: String? { after.isEmpty ? nil : after }

    public func insertText(_ text: String) {
        selected = ""
        before += text
    }

    public func deleteBackward() {
        if !selected.isEmpty {
            selected = ""
            return
        }
        // `removeLast` drops one `Character`, i.e. one extended grapheme
        // cluster — the same unit a real backspace removes.
        if !before.isEmpty {
            before.removeLast()
        }
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --package-path Packages/TextReplacement`

Expected: `Test run with 6 tests passed`.

- [ ] **Step 7: Commit**

```bash
git add Packages/TextReplacement
git commit -m "feat(TextReplacement): add proxy protocol and in-memory stub"
```

---

### Task 3: Capture policy

**Files:**
- Create: `Packages/TextReplacement/Sources/TextReplacement/CapturedText.swift`
- Create: `Packages/TextReplacement/Sources/TextReplacement/TextCapture.swift`
- Test: `Packages/TextReplacement/Tests/TextReplacementTests/TextCaptureTests.swift`

**Interfaces:**
- Consumes: `TextDocumentProxying`, `StubTextDocumentProxy` (Task 2)
- Produces:
  - `struct CapturedText: Equatable, Sendable` with `enum Source: Equatable, Sendable { case selection, contextBefore }`, `let text: String`, `let source: Source`, `init(text: String, source: Source)`
  - `enum CaptureOutcome: Equatable, Sendable { case captured(CapturedText), selectionTooLong(count: Int), empty }`
  - `enum TextCapture` with `static let defaultMaxChars = 2000` and `static func capture(from proxy: any TextDocumentProxying, maxChars: Int = defaultMaxChars) -> CaptureOutcome`

- [ ] **Step 1: Write the failing test**

`Packages/TextReplacement/Tests/TextReplacementTests/TextCaptureTests.swift`:

```swift
import Testing
@testable import TextReplacement

@Suite("TextCapture")
struct TextCaptureTests {
    @Test func selectionWinsOverContext() {
        let proxy = StubTextDocumentProxy(before: "context text", selected: "chosen", after: "")
        #expect(TextCapture.capture(from: proxy) == .captured(
            CapturedText(text: "chosen", source: .selection)))
    }

    @Test func blankSelectionFallsThroughToContext() {
        let proxy = StubTextDocumentProxy(before: "the draft", selected: "   \n ", after: "")
        #expect(TextCapture.capture(from: proxy) == .captured(
            CapturedText(text: "the draft", source: .contextBefore)))
    }

    @Test func emptyFieldYieldsEmpty() {
        #expect(TextCapture.capture(from: StubTextDocumentProxy()) == .empty)
    }

    @Test func blankContextYieldsEmpty() {
        let proxy = StubTextDocumentProxy(before: "   \n\t ", after: "")
        #expect(TextCapture.capture(from: proxy) == .empty)
    }

    @Test func afterContextIsIgnored() {
        let proxy = StubTextDocumentProxy(before: "", selected: "", after: "trailing text")
        #expect(TextCapture.capture(from: proxy) == .empty)
    }

    @Test func overLongContextKeepsTrailingCharacters() {
        let long = String(repeating: "a", count: 40) + "TAIL"
        let proxy = StubTextDocumentProxy(before: long, after: "")
        let outcome = TextCapture.capture(from: proxy, maxChars: 10)
        #expect(outcome == .captured(CapturedText(text: "aaaaaaTAIL", source: .contextBefore)))
    }

    @Test func overLongSelectionIsRejectedNotClamped() {
        let long = String(repeating: "b", count: 25)
        let proxy = StubTextDocumentProxy(before: "x", selected: long, after: "")
        #expect(TextCapture.capture(from: proxy, maxChars: 10) == .selectionTooLong(count: 25))
    }

    @Test func selectionExactlyAtLimitIsAccepted() {
        let exact = String(repeating: "c", count: 10)
        let proxy = StubTextDocumentProxy(selected: exact)
        #expect(TextCapture.capture(from: proxy, maxChars: 10) == .captured(
            CapturedText(text: exact, source: .selection)))
    }

    @Test func lengthsAreCountedInGraphemeClusters() {
        // Five flags: 5 graphemes, 20 UTF-16 units. Must be accepted at maxChars 10.
        let flags = String(repeating: "\u{1F1FA}\u{1F1E6}", count: 5)
        let proxy = StubTextDocumentProxy(selected: flags)
        #expect(TextCapture.capture(from: proxy, maxChars: 10) == .captured(
            CapturedText(text: flags, source: .selection)))
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --package-path Packages/TextReplacement --filter TextCapture`

Expected: compile failure — `cannot find 'TextCapture' in scope`.

- [ ] **Step 3: Write `CapturedText.swift`**

```swift
import Foundation

/// Text pulled out of the host app's field, tagged with how it was obtained.
///
/// `source` determines the delete arithmetic in `ReplacementPlan`, so it must
/// always reflect the field's *current* state, not how the text originally
/// arrived.
public struct CapturedText: Equatable, Sendable {
    public enum Source: Equatable, Sendable {
        /// The user had text selected. One `deleteBackward()` clears all of it.
        case selection
        /// No selection; text was read from `documentContextBeforeInput`.
        /// Requires one `deleteBackward()` per grapheme cluster.
        case contextBefore
    }

    public let text: String
    public let source: Source

    public init(text: String, source: Source) {
        self.text = text
        self.source = source
    }
}

public enum CaptureOutcome: Equatable, Sendable {
    case captured(CapturedText)
    /// The selection exceeds `maxChars`. Deliberately not clamped — see `TextCapture`.
    case selectionTooLong(count: Int)
    case empty
}
```

- [ ] **Step 4: Write `TextCapture.swift`**

```swift
import Foundation

public enum TextCapture {
    /// Matches `TextEditorBox(maxChars: 2000)` in the host app.
    public static let defaultMaxChars = 2000

    /// Selection first, then the text before the cursor.
    ///
    /// An over-long *selection* is rejected rather than clamped. A `.selection`
    /// plan deletes with a single `deleteBackward()`, which clears the entire
    /// selection regardless of how much of it was captured — so clamping a
    /// 5000-character selection to its trailing 2000 would delete all 5000 and
    /// insert a rewrite of the last 2000, silently destroying 3000 characters.
    /// Clamping is safe only for `.contextBefore`, where the delete count is
    /// derived from the clamped string itself.
    public static func capture(
        from proxy: any TextDocumentProxying,
        maxChars: Int = defaultMaxChars
    ) -> CaptureOutcome {
        if let selected = proxy.selectedText, !isBlank(selected) {
            if selected.count > maxChars {
                return .selectionTooLong(count: selected.count)
            }
            return .captured(CapturedText(text: selected, source: .selection))
        }

        if let before = proxy.documentContextBeforeInput, !isBlank(before) {
            return .captured(CapturedText(text: clamp(before, to: maxChars), source: .contextBefore))
        }

        return .empty
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func clamp(_ text: String, to maxChars: Int) -> String {
        guard text.count > maxChars else { return text }
        return String(text.suffix(maxChars))
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --package-path Packages/TextReplacement`

Expected: all tests pass (6 from Task 2 + 9 here = 15).

- [ ] **Step 6: Commit**

```bash
git add Packages/TextReplacement
git commit -m "feat(TextReplacement): add selection-first capture policy"
```

---

### Task 4: Replacement and undo arithmetic

**Files:**
- Create: `Packages/TextReplacement/Sources/TextReplacement/ReplacementPlan.swift`
- Create: `Packages/TextReplacement/Sources/TextReplacement/TextReplacer.swift`
- Create: `Packages/TextReplacement/Tests/TextReplacementTests/UnicodeCorpus.swift`
- Test: `Packages/TextReplacement/Tests/TextReplacementTests/ReplacementPlanTests.swift`

**Interfaces:**
- Consumes: `CapturedText`, `TextDocumentProxying`, `StubTextDocumentProxy` (Tasks 2–3)
- Produces:
  - `struct ReplacementPlan: Equatable, Sendable` with `let deleteCount: Int`, `let insert: String`, `init(deleteCount: Int, insert: String)`, `static func replacing(_ captured: CapturedText, with text: String) -> ReplacementPlan`, `static func undoing(_ plan: ReplacementPlan, restoring captured: CapturedText) -> ReplacementPlan`
  - `enum TextReplacer` with `static func apply(_ plan: ReplacementPlan, to proxy: any TextDocumentProxying)`
  - Test fixture `enum UnicodeCorpus` with `static let samples: [(name: String, text: String)]`

- [ ] **Step 1: Write the shared Unicode fixture**

`Packages/TextReplacement/Tests/TextReplacementTests/UnicodeCorpus.swift`:

```swift
import Foundation

/// Strings whose grapheme-cluster count differs from their UTF-16 count.
/// Every one of these is a case where using `utf16.count` as a delete count
/// would over-delete and eat text the user never selected.
enum UnicodeCorpus {
    static let samples: [(name: String, text: String)] = [
        ("ascii", "hello world"),
        ("emoji", "nice \u{1F44D}"),
        ("zwjFamily", "family \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}"),
        ("flag", "from \u{1F1FA}\u{1F1E6}"),
        ("combiningAccent", "caf\u{65}\u{301}"),
        ("crlf", "line one\r\nline two"),
        ("mixed", "ok \u{1F44D}\u{1F1FA}\u{1F1E6} caf\u{65}\u{301}\r\ndone"),
    ]
}
```

- [ ] **Step 2: Write the failing test**

`Packages/TextReplacement/Tests/TextReplacementTests/ReplacementPlanTests.swift`:

```swift
import Testing
@testable import TextReplacement

@Suite("ReplacementPlan")
struct ReplacementPlanTests {
    @Test func selectionPlanAlwaysDeletesExactlyOnce() {
        let captured = CapturedText(text: "a very long selected sentence", source: .selection)
        let plan = ReplacementPlan.replacing(captured, with: "rewritten")
        #expect(plan.deleteCount == 1)
        #expect(plan.insert == "rewritten")
    }

    @Test func contextPlanDeletesOnePerGraphemeCluster() {
        let captured = CapturedText(text: "hello", source: .contextBefore)
        let plan = ReplacementPlan.replacing(captured, with: "hi")
        #expect(plan.deleteCount == 5)
    }

    @Test(arguments: UnicodeCorpus.samples)
    func contextDeleteCountUsesGraphemesNotUTF16(sample: (name: String, text: String)) {
        let captured = CapturedText(text: sample.text, source: .contextBefore)
        let plan = ReplacementPlan.replacing(captured, with: "x")
        #expect(plan.deleteCount == sample.text.count, "\(sample.name)")
    }

    @Test func undoPlanDeletesTheInsertedTextAndRestoresTheOriginal() {
        let captured = CapturedText(text: "original words", source: .selection)
        let plan = ReplacementPlan.replacing(captured, with: "new \u{1F44D}")
        let undo = ReplacementPlan.undoing(plan, restoring: captured)
        #expect(undo.deleteCount == 5)   // "new " + one emoji grapheme
        #expect(undo.insert == "original words")
    }

    @Test func applyDeletesThenInserts() {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: " now")
        let captured = CapturedText(text: "hello", source: .selection)
        TextReplacer.apply(ReplacementPlan.replacing(captured, with: "greetings"), to: proxy)
        #expect(proxy.document == "Say greetings now")
    }

    @Test func applyOnContextSourceDeletesOnlyTheCapturedSpan() {
        let proxy = StubTextDocumentProxy(before: "keep this hello", after: "")
        let captured = CapturedText(text: "hello", source: .contextBefore)
        TextReplacer.apply(ReplacementPlan.replacing(captured, with: "goodbye"), to: proxy)
        #expect(proxy.document == "keep this goodbye")
    }

    @Test func applyWithZeroDeleteCountOnlyInserts() {
        let proxy = StubTextDocumentProxy(before: "abc", after: "")
        TextReplacer.apply(ReplacementPlan(deleteCount: 0, insert: "def"), to: proxy)
        #expect(proxy.document == "abcdef")
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --package-path Packages/TextReplacement --filter ReplacementPlan`

Expected: compile failure — `cannot find 'ReplacementPlan' in scope`.

- [ ] **Step 4: Write `ReplacementPlan.swift`**

```swift
import Foundation

/// A backspace count plus the string to type. The only two numbers that can
/// destroy the user's text, so they live in one small, heavily tested type.
public struct ReplacementPlan: Equatable, Sendable {
    public let deleteCount: Int
    public let insert: String

    public init(deleteCount: Int, insert: String) {
        self.deleteCount = deleteCount
        self.insert = insert
    }

    public static func replacing(_ captured: CapturedText, with text: String) -> ReplacementPlan {
        switch captured.source {
        case .selection:
            // A single `deleteBackward()` clears an entire selection atomically.
            return ReplacementPlan(deleteCount: 1, insert: text)
        case .contextBefore:
            // `deleteBackward()` removes one user-perceived character, so the
            // count is grapheme clusters. `utf16.count` would over-delete on
            // emoji, flags, and combining marks.
            return ReplacementPlan(deleteCount: captured.text.count, insert: text)
        }
    }

    /// The inverse of `plan`, assuming `plan.insert` still sits immediately
    /// behind the cursor. Callers must invalidate the undo plan on any external
    /// edit — see `KeyboardPanelViewModel`.
    public static func undoing(
        _ plan: ReplacementPlan,
        restoring captured: CapturedText
    ) -> ReplacementPlan {
        ReplacementPlan(deleteCount: plan.insert.count, insert: captured.text)
    }
}
```

- [ ] **Step 5: Write `TextReplacer.swift`**

```swift
import Foundation

public enum TextReplacer {
    public static func apply(_ plan: ReplacementPlan, to proxy: any TextDocumentProxying) {
        for _ in 0..<max(0, plan.deleteCount) {
            proxy.deleteBackward()
        }
        proxy.insertText(plan.insert)
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --package-path Packages/TextReplacement`

Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add Packages/TextReplacement
git commit -m "feat(TextReplacement): add replacement and undo plan arithmetic"
```

---

### Task 5: Round-trip safety property

**Files:**
- Test: `Packages/TextReplacement/Tests/TextReplacementTests/RoundTripTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 2–4
- Produces: no new source. This task adds the feature's primary safety guarantee as an executable property.

- [ ] **Step 1: Write the property test**

`Packages/TextReplacement/Tests/TextReplacementTests/RoundTripTests.swift`:

```swift
import Testing
@testable import TextReplacement

@Suite("Replace/undo round trip")
struct RoundTripTests {
    @Test(arguments: UnicodeCorpus.samples)
    func selectionRoundTripRestoresDocumentExactly(sample: (name: String, text: String)) {
        let proxy = StubTextDocumentProxy(before: "PRE ", selected: sample.text, after: " POST")
        let start = proxy.document

        guard case .captured(let captured) = TextCapture.capture(from: proxy) else {
            Issue.record("expected a capture for \(sample.name)")
            return
        }
        #expect(captured.source == .selection)

        let plan = ReplacementPlan.replacing(captured, with: "REWRITTEN \u{1F44D}")
        TextReplacer.apply(plan, to: proxy)
        #expect(proxy.document == "PRE REWRITTEN \u{1F44D} POST", "\(sample.name)")

        // After a replacement there is no selection, so the restored text must
        // be re-sourced as `.contextBefore` for any subsequent operation.
        TextReplacer.apply(ReplacementPlan.undoing(plan, restoring: captured), to: proxy)
        #expect(proxy.document == start, "\(sample.name)")
    }

    @Test(arguments: UnicodeCorpus.samples)
    func contextRoundTripRestoresDocumentExactly(sample: (name: String, text: String)) {
        let proxy = StubTextDocumentProxy(before: sample.text, after: "")
        let start = proxy.document

        guard case .captured(let captured) = TextCapture.capture(from: proxy) else {
            Issue.record("expected a capture for \(sample.name)")
            return
        }
        #expect(captured.source == .contextBefore)

        let plan = ReplacementPlan.replacing(captured, with: "REWRITTEN")
        TextReplacer.apply(plan, to: proxy)
        #expect(proxy.document == "REWRITTEN", "\(sample.name)")

        TextReplacer.apply(ReplacementPlan.undoing(plan, restoring: captured), to: proxy)
        #expect(proxy.document == start, "\(sample.name)")
    }

    @Test func contextReplacementNeverTouchesTextBeforeTheCapturedSpan() {
        // Regression guard: a UTF-16 delete count would eat into "UNTOUCHED".
        let proxy = StubTextDocumentProxy(before: "UNTOUCHED \u{1F1FA}\u{1F1E6}\u{1F44D}", after: "")
        let captured = CapturedText(text: "\u{1F1FA}\u{1F1E6}\u{1F44D}", source: .contextBefore)
        TextReplacer.apply(ReplacementPlan.replacing(captured, with: "ok"), to: proxy)
        #expect(proxy.document == "UNTOUCHED ok")
    }

    @Test func secondReplacementAfterUndoUsesContextSemantics() {
        let proxy = StubTextDocumentProxy(before: "Draft: ", selected: "old text", after: "")
        guard case .captured(let captured) = TextCapture.capture(from: proxy) else {
            Issue.record("expected a capture"); return
        }
        let plan = ReplacementPlan.replacing(captured, with: "first")
        TextReplacer.apply(plan, to: proxy)
        TextReplacer.apply(ReplacementPlan.undoing(plan, restoring: captured), to: proxy)

        // The restored text is no longer selected, so it must be re-sourced.
        let restored = CapturedText(text: captured.text, source: .contextBefore)
        TextReplacer.apply(ReplacementPlan.replacing(restored, with: "second"), to: proxy)
        #expect(proxy.document == "Draft: second")
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `swift test --package-path Packages/TextReplacement`

Expected: all pass. If `secondReplacementAfterUndoUsesContextSemantics` fails, the re-sourcing rule is wrong — do not proceed to Task 6 until it passes.

- [ ] **Step 3: Run lint**

Run: `./scripts/lint.sh`

Expected: no output beyond swift-format's own diagnostics; exit code 0.

- [ ] **Step 4: Commit**

```bash
git add Packages/TextReplacement
git commit -m "test(TextReplacement): add replace/undo round-trip property"
```

---

## Phase 2 — KeyboardUI package

### Task 6: Scaffold KeyboardUI with the panel state machine

**Files:**
- Create: `Packages/KeyboardUI/Package.swift`
- Create: `Packages/KeyboardUI/Sources/KeyboardUI/KeyboardPanelState.swift`
- Create: `Packages/KeyboardUI/Sources/KeyboardUI/KeyboardPanelViewModel.swift`
- Test: `Packages/KeyboardUI/Tests/KeyboardUITests/KeyboardPanelViewModelTests.swift`

**Interfaces:**
- Consumes: `CapturedText`, `CaptureOutcome`, `TextCapture`, `ReplacementPlan`, `TextReplacer`, `TextDocumentProxying`, `StubTextDocumentProxy` (Phase 1); `EnhancementViewModel` (EnhancerUI); `Preset` (PresetKit); `LanguageModelAvailability`, `Enhancer`, `StubLanguageModelProvider` (EnhancerCore)
- Produces:
  - `enum KeyboardPanelState: Equatable` with cases `needsText`, `selectionTooLong(count: Int)`, `ready(CapturedText)`, `enhancing(CapturedText)`, `replaced(undo: ReplacementPlan, original: CapturedText)`, `unavailable(LanguageModelAvailability.Reason)`
  - `@Observable @MainActor final class KeyboardPanelViewModel` with `init(proxy:enhancement:availability:activePresets:hasFullAccess:maxChars:)`, `var state: KeyboardPanelState { get }`, `let enhancement: EnhancementViewModel`, `let hasFullAccess: Bool`, `func onAppear() async`, `func textDidChange()`, `func selectionDidChange()`

- [ ] **Step 1: Create the package manifest**

`Packages/KeyboardUI/Package.swift`:

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "KeyboardUI",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [.library(name: "KeyboardUI", targets: ["KeyboardUI"])],
    dependencies: [
        .package(path: "../EnhancerCore"),
        .package(path: "../PresetKit"),
        .package(path: "../EnhancerUI"),
        .package(path: "../TextReplacement"),
    ],
    targets: [
        .target(
            name: "KeyboardUI",
            dependencies: [
                .product(name: "EnhancerCore", package: "EnhancerCore"),
                .product(name: "PresetKit", package: "PresetKit"),
                .product(name: "EnhancerUI", package: "EnhancerUI"),
                .product(name: "TextReplacement", package: "TextReplacement"),
            ]),
        .testTarget(name: "KeyboardUITests", dependencies: ["KeyboardUI"]),
    ]
)
```

- [ ] **Step 2: Write the failing test**

`Packages/KeyboardUI/Tests/KeyboardUITests/KeyboardPanelViewModelTests.swift`:

```swift
import Testing
import Foundation
import EnhancerCore
import PresetKit
import EnhancerUI
import TextReplacement
@testable import KeyboardUI

@MainActor
@Suite("KeyboardPanelViewModel")
struct KeyboardPanelViewModelTests {
    private func makePresets() -> [Preset] {
        [Preset(label: "Professional", instructions: "Be professional.", isBuiltIn: true, sortOrder: 0)]
    }

    private func makeViewModel(
        proxy: StubTextDocumentProxy,
        availability: LanguageModelAvailability = .available,
        chunks: [String] = ["polished text"],
        hasFullAccess: Bool = true,
        maxChars: Int = TextCapture.defaultMaxChars
    ) -> KeyboardPanelViewModel {
        let provider = StubLanguageModelProvider(availability: availability, scriptedChunks: chunks)
        return KeyboardPanelViewModel(
            proxy: proxy,
            enhancement: EnhancementViewModel(enhancer: Enhancer(provider: provider)),
            availability: availability,
            activePresets: makePresets(),
            hasFullAccess: hasFullAccess,
            maxChars: maxChars
        )
    }

    @Test func unavailableShortCircuitsBeforeCapture() async {
        let proxy = StubTextDocumentProxy(before: "some text")
        let vm = makeViewModel(proxy: proxy, availability: .unavailable(.deviceNotEligible))
        await vm.onAppear()
        #expect(vm.state == .unavailable(.deviceNotEligible))
    }

    @Test func emptyFieldLandsInNeedsText() async {
        let vm = makeViewModel(proxy: StubTextDocumentProxy())
        await vm.onAppear()
        #expect(vm.state == .needsText)
    }

    @Test func overLongSelectionLandsInSelectionTooLong() async {
        let proxy = StubTextDocumentProxy(selected: String(repeating: "z", count: 30))
        let vm = makeViewModel(proxy: proxy, maxChars: 10)
        await vm.onAppear()
        #expect(vm.state == .selectionTooLong(count: 30))
    }

    @Test func capturedTextAutoStartsAndReturnsToReady() async {
        let proxy = StubTextDocumentProxy(before: "Hi ", selected: "there", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()
        #expect(vm.state == .ready(CapturedText(text: "there", source: .selection)))
        #expect(vm.enhancement.inputText == "there")
        #expect(vm.enhancement.variantStates.count == 1)
    }

    @Test func selectionChangeRetargetsCapture() async {
        let proxy = StubTextDocumentProxy(before: "first draft")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()
        #expect(vm.state == .ready(CapturedText(text: "first draft", source: .contextBefore)))

        proxy.before = "first "
        proxy.selected = "draft"
        vm.selectionDidChange()
        #expect(vm.state == .ready(CapturedText(text: "draft", source: .selection)))
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --package-path Packages/KeyboardUI`

Expected: compile failure — `cannot find 'KeyboardPanelViewModel' in scope`.

- [ ] **Step 4: Write `KeyboardPanelState.swift`**

```swift
import Foundation
import EnhancerCore
import TextReplacement

public enum KeyboardPanelState: Equatable {
    /// Nothing usable in the field.
    case needsText
    /// The selection is larger than we will operate on. Never clamped — see `TextCapture`.
    case selectionTooLong(count: Int)
    /// Text captured, variants may be shown and tapped.
    case ready(CapturedText)
    /// A generation is in flight. Re-capture is suppressed in this state.
    case enhancing(CapturedText)
    /// Text was replaced and can be undone while `undo` remains valid.
    case replaced(undo: ReplacementPlan, original: CapturedText)
    case unavailable(LanguageModelAvailability.Reason)
}
```

- [ ] **Step 5: Write `KeyboardPanelViewModel.swift`**

```swift
import Foundation
import Observation
import EnhancerCore
import PresetKit
import EnhancerUI
import TextReplacement

@Observable
@MainActor
public final class KeyboardPanelViewModel {
    public private(set) var state: KeyboardPanelState = .needsText
    public let enhancement: EnhancementViewModel
    public let hasFullAccess: Bool

    private let proxy: any TextDocumentProxying
    private let availability: LanguageModelAvailability
    private let activePresets: [Preset]
    private let maxChars: Int

    /// True while we are the ones editing the document. The host fires
    /// `textDidChange` for our own `insertText`/`deleteBackward` calls, and
    /// re-capturing mid-replacement would corrupt the plan.
    private var isApplyingEdit = false

    public init(
        proxy: any TextDocumentProxying,
        enhancement: EnhancementViewModel,
        availability: LanguageModelAvailability,
        activePresets: [Preset],
        hasFullAccess: Bool,
        maxChars: Int = TextCapture.defaultMaxChars
    ) {
        self.proxy = proxy
        self.enhancement = enhancement
        self.availability = availability
        self.activePresets = activePresets
        self.hasFullAccess = hasFullAccess
        self.maxChars = maxChars
    }

    public func onAppear() async {
        if case .unavailable(let reason) = availability {
            state = .unavailable(reason)
            return
        }
        recapture()
        await startIfReady()
    }

    public func textDidChange() { handleExternalChange() }
    public func selectionDidChange() { handleExternalChange() }

    private func handleExternalChange() {
        guard !isApplyingEdit else { return }
        switch state {
        case .enhancing, .unavailable:
            return
        case .needsText, .selectionTooLong, .ready, .replaced:
            // Falling through from `.replaced` is deliberate: any external edit
            // invalidates the undo plan, whose delete count assumes the inserted
            // text is still immediately behind the cursor.
            recapture()
        }
    }

    private func recapture() {
        switch TextCapture.capture(from: proxy, maxChars: maxChars) {
        case .captured(let captured):
            state = .ready(captured)
        case .selectionTooLong(let count):
            state = .selectionTooLong(count: count)
        case .empty:
            state = .needsText
        }
    }

    private func startIfReady() async {
        guard case .ready(let captured) = state else { return }
        state = .enhancing(captured)
        await enhancement.start(inputText: captured.text, activePresets: activePresets)
        await enhancement.waitForCompletion()
        if case .enhancing = state {
            state = .ready(captured)
        }
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeyboardUI`

Expected: 5 tests pass.

- [ ] **Step 7: Commit**

```bash
git add Packages/KeyboardUI
git commit -m "feat(KeyboardUI): add panel state machine with capture and auto-start"
```

---

### Task 7: Replace, undo, and undo invalidation

**Files:**
- Modify: `Packages/KeyboardUI/Sources/KeyboardUI/KeyboardPanelViewModel.swift`
- Test: `Packages/KeyboardUI/Tests/KeyboardUITests/KeyboardPanelViewModelTests.swift`

**Interfaces:**
- Consumes: everything from Task 6
- Produces: `func select(variantText: String)` and `func undo()` on `KeyboardPanelViewModel`

- [ ] **Step 1: Write the failing tests**

Append these to the `KeyboardPanelViewModelTests` suite in `Packages/KeyboardUI/Tests/KeyboardUITests/KeyboardPanelViewModelTests.swift`:

```swift
    @Test func selectingAVariantReplacesTextAndOffersUndo() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: " now")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        #expect(proxy.document == "Say greetings now")
        guard case .replaced(_, let original) = vm.state else {
            Issue.record("expected .replaced, got \(vm.state)"); return
        }
        #expect(original.text == "hello")
    }

    @Test func undoRestoresTheOriginalDocument() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: " now")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        vm.undo()
        #expect(proxy.document == "Say hello now")
    }

    @Test func undoReSourcesTheCaptureToContextBefore() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        vm.undo()

        // The restored text is no longer selected. Carrying `.selection`
        // forward would make the next replacement delete exactly one character.
        #expect(vm.state == .ready(CapturedText(text: "hello", source: .contextBefore)))

        vm.select(variantText: "howdy")
        #expect(proxy.document == "Say howdy")
    }

    @Test func externalEditWhileReplacedInvalidatesUndo() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        // The user types a word before tapping undo.
        proxy.before += " everyone"
        vm.textDidChange()

        guard case .ready = vm.state else {
            Issue.record("expected .ready after external edit, got \(vm.state)"); return
        }
        vm.undo()   // must be a no-op now
        #expect(proxy.document == "Say greetings everyone")
    }

    @Test func ourOwnEditsDoNotTriggerRecapture() async {
        let proxy = StubTextDocumentProxy(before: "Say ", selected: "hello", after: "")
        let vm = makeViewModel(proxy: proxy)
        await vm.onAppear()

        vm.select(variantText: "greetings")
        guard case .replaced = vm.state else {
            Issue.record("expected .replaced, got \(vm.state)"); return
        }
    }

    @Test func selectIsIgnoredWhenNotReady() async {
        let vm = makeViewModel(proxy: StubTextDocumentProxy())
        await vm.onAppear()
        #expect(vm.state == .needsText)
        vm.select(variantText: "anything")
        #expect(vm.state == .needsText)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --package-path Packages/KeyboardUI`

Expected: compile failure — `value of type 'KeyboardPanelViewModel' has no member 'select'`.

- [ ] **Step 3: Add `select` and `undo`**

Insert these methods into `KeyboardPanelViewModel`, immediately after `public func selectionDidChange()`:

```swift
    /// Replace the captured span with `variantText` and arm the undo plan.
    public func select(variantText: String) {
        guard case .ready(let captured) = state else { return }
        let plan = ReplacementPlan.replacing(captured, with: variantText)
        applyingEdit { TextReplacer.apply(plan, to: proxy) }
        state = .replaced(undo: .undoing(plan, restoring: captured), original: captured)
    }

    /// Restore the text as it was before the last replacement.
    ///
    /// The restored capture is re-sourced to `.contextBefore` because the text
    /// is no longer selected, even when the original capture came from a
    /// selection. Keeping `.selection` here would make the next replacement
    /// emit `deleteCount == 1` against an unselected field, deleting a single
    /// character instead of the whole span.
    public func undo() {
        guard case .replaced(let undoPlan, let original) = state else { return }
        applyingEdit { TextReplacer.apply(undoPlan, to: proxy) }
        state = .ready(CapturedText(text: original.text, source: .contextBefore))
    }

    private func applyingEdit(_ body: () -> Void) {
        isApplyingEdit = true
        body()
        isApplyingEdit = false
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --package-path Packages/KeyboardUI`

Expected: 11 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages/KeyboardUI
git commit -m "feat(KeyboardUI): add replace, undo, and undo invalidation"
```

---

### Task 8: Panel views

**Files:**
- Create: `Packages/KeyboardUI/Sources/KeyboardUI/CompactVariantRow.swift`
- Create: `Packages/KeyboardUI/Sources/KeyboardUI/CapturedTextStrip.swift`
- Create: `Packages/KeyboardUI/Sources/KeyboardUI/FullAccessPromptRow.swift`
- Create: `Packages/KeyboardUI/Sources/KeyboardUI/KeyboardPanel.swift`

**Interfaces:**
- Consumes: `KeyboardPanelViewModel`, `KeyboardPanelState` (Tasks 6–7); `VariantViewState` (EnhancerUI)
- Produces:
  - `struct CompactVariantRow: View` with `init(state: VariantViewState, onUse: @escaping () -> Void)`
  - `struct CapturedTextStrip: View` with `init(text: String, isClamped: Bool)`
  - `struct FullAccessPromptRow: View` with `init(onDismiss: @escaping () -> Void)`
  - `struct KeyboardPanel: View` with `init(viewModel: KeyboardPanelViewModel, isFullAccessPromptDismissed: Bool, onDismissFullAccessPrompt: @escaping () -> Void)`
  - Accessibility identifiers consumed by Task 12: `keyboardPanel.needsText`, `keyboardPanel.undo`, `keyboardPanel.replacedConfirmation`, `keyboardPanel.variantRow`

There is no unit test for this task — these are pure layout. Their behaviour is exercised through `KeyboardPanelViewModel` tests (Tasks 6–7) and the UI test in Task 12.

- [ ] **Step 1: Write `CompactVariantRow.swift`**

```swift
import SwiftUI
import EnhancerCore
import EnhancerUI

/// A variant at keyboard density: one line of label, two lines of text, one button.
public struct CompactVariantRow: View {
    public let state: VariantViewState
    public let onUse: () -> Void

    public init(state: VariantViewState, onUse: @escaping () -> Void) {
        self.state = state
        self.onUse = onUse
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.presetLabel.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)

                switch state.phase {
                case .waiting:
                    Text("Waiting…").font(.footnote).foregroundStyle(.secondary).italic()
                case .streaming:
                    Text(state.text.isEmpty ? "Generating…" : state.text)
                        .font(.footnote)
                        .foregroundStyle(state.text.isEmpty ? .secondary : .primary)
                        .italic(state.text.isEmpty)
                        .lineLimit(2)
                case .completed:
                    Text(state.text).font(.footnote).lineLimit(2)
                case .failed(let error):
                    Text(error.userFacingMessage).font(.footnote).foregroundStyle(.red).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Use", action: onUse)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(state.phase != .completed)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("keyboardPanel.variantRow")
    }
}
```

- [ ] **Step 2: Write `CapturedTextStrip.swift`**

```swift
import SwiftUI

/// Shows exactly what will be rewritten.
///
/// Hosts truncate `documentContextBeforeInput` at around 300 characters and we
/// cannot detect when that happened, so we show the captured text rather than
/// letting the user assume their whole draft is in play.
public struct CapturedTextStrip: View {
    public let text: String
    public let isClamped: Bool

    public init(text: String, isClamped: Bool) {
        self.text = text
        self.isClamped = isClamped
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if isClamped {
                Text("Rewriting the last \(text.count) characters.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .accessibilityIdentifier("keyboardPanel.capturedStrip")
    }
}
```

- [ ] **Step 3: Write `FullAccessPromptRow.swift`**

```swift
import SwiftUI

/// A keyboard extension cannot reach `UIApplication.shared`, so this cannot
/// deep-link into Settings. It shows the path as text instead.
public struct FullAccessPromptRow: View {
    public let onDismiss: () -> Void

    public init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Using built-in presets only")
                    .font(.caption.weight(.semibold))
                Text("For your custom presets and Recents: Settings → General → Keyboard → Keyboards → TalkNative → Allow Full Access")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Dismiss", systemImage: "xmark", action: onDismiss)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .accessibilityIdentifier("keyboardPanel.fullAccessPrompt")
    }
}
```

- [ ] **Step 4: Write `KeyboardPanel.swift`**

```swift
import SwiftUI
import EnhancerCore
import EnhancerUI
import TextReplacement

public struct KeyboardPanel: View {
    @State private var viewModel: KeyboardPanelViewModel
    private let isFullAccessPromptDismissed: Bool
    private let onDismissFullAccessPrompt: () -> Void

    public init(
        viewModel: KeyboardPanelViewModel,
        isFullAccessPromptDismissed: Bool,
        onDismissFullAccessPrompt: @escaping () -> Void
    ) {
        self._viewModel = State(initialValue: viewModel)
        self.isFullAccessPromptDismissed = isFullAccessPromptDismissed
        self.onDismissFullAccessPrompt = onDismissFullAccessPrompt
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !viewModel.hasFullAccess && !isFullAccessPromptDismissed {
                FullAccessPromptRow(onDismiss: onDismissFullAccessPrompt)
            }

            switch viewModel.state {
            case .needsText:
                message("Select the text you want to rewrite, or type something first.")
                    .accessibilityIdentifier("keyboardPanel.needsText")

            case .selectionTooLong(let count):
                message("That selection is \(count) characters. Select up to \(TextCapture.defaultMaxChars).")
                    .accessibilityIdentifier("keyboardPanel.selectionTooLong")

            case .unavailable(let reason):
                message(EnhancerError.modelUnavailable(reason).userFacingMessage)
                    .accessibilityIdentifier("keyboardPanel.unavailable")

            case .ready(let captured):
                CapturedTextStrip(
                    text: captured.text,
                    isClamped: captured.text.count == TextCapture.defaultMaxChars)
                variantRows(isEnabled: true)

            case .enhancing(let captured):
                CapturedTextStrip(
                    text: captured.text,
                    isClamped: captured.text.count == TextCapture.defaultMaxChars)
                variantRows(isEnabled: false)

            case .replaced:
                replacedStrip
                variantRows(isEnabled: false)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .task { await viewModel.onAppear() }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
    }

    private var replacedStrip: some View {
        HStack(spacing: 8) {
            Label("Replaced", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            Spacer()
            Button("Undo") { viewModel.undo() }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("keyboardPanel.undo")
        }
        .padding(.horizontal, 10)
        .accessibilityIdentifier("keyboardPanel.replacedConfirmation")
    }

    /// Rows stay visible after a replacement but go inert. Undoing first keeps
    /// the undo plan's precondition — inserted text immediately behind the
    /// cursor — trivially true.
    private func variantRows(isEnabled: Bool) -> some View {
        VStack(spacing: 6) {
            ForEach(viewModel.enhancement.variantStates) { state in
                CompactVariantRow(state: state) {
                    viewModel.select(variantText: state.text)
                }
            }
        }
        .padding(.horizontal, 10)
        .disabled(!isEnabled)
    }
}
```

- [ ] **Step 5: Build and test the package**

Run: `swift test --package-path Packages/KeyboardUI`

Expected: builds cleanly; the 11 existing tests still pass.

- [ ] **Step 6: Verify no UIKit crept in**

Run: `grep -rn "import UIKit" Packages/KeyboardUI Packages/TextReplacement`

Expected: no output. If there is any, remove it — both packages must build on macOS.

- [ ] **Step 7: Commit**

```bash
git add Packages/KeyboardUI
git commit -m "feat(KeyboardUI): add keyboard-density panel views"
```

---

## Phase 3 — Keyboard extension target

### Task 9: Create the target and wire the proxy adapter

**Files:**
- Modify: `project.yml`
- Create: `TalkNativeKeyboard/Info.plist`
- Create: `TalkNativeKeyboard/TalkNativeKeyboard.entitlements`
- Create: `TalkNativeKeyboard/LiveTextDocumentProxy.swift`
- Create: `TalkNativeKeyboard/KeyboardInputViewController.swift`

**Interfaces:**
- Consumes: `KeyboardPanel`, `KeyboardPanelViewModel` (Phase 2); `TextDocumentProxying` (Phase 1)
- Produces: `final class LiveTextDocumentProxy: TextDocumentProxying` with `init(_ proxy: UITextDocumentProxy)`; `final class KeyboardInputViewController: UIInputViewController`

- [ ] **Step 1: Add both packages to `project.yml`**

In the `packages:` map, add:

```yaml
  TextReplacement: { path: Packages/TextReplacement }
  KeyboardUI:      { path: Packages/KeyboardUI }
```

- [ ] **Step 2: Add the keyboard target to `project.yml`**

Add to the `targets:` map, after the `EnhanceExtension` block:

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

`RequestsOpenAccess: true` makes Full Access grantable; it does not make it required.

- [ ] **Step 3: Embed the keyboard in the app**

In the `TalkNative` target's `dependencies:` list, immediately after the `EnhanceExtension` entry, add:

```yaml
      - target: TalkNativeKeyboard
        embed: true
```

Also add `TalkNativeKeyboard` to `options.groupOrdering[0].order`, so it reads:

```yaml
    - order: [TalkNative, EnhanceExtension, TalkNativeKeyboard, Packages, docs, scripts]
```

- [ ] **Step 4: Create the plist and entitlements**

`TalkNativeKeyboard/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

`TalkNativeKeyboard/TalkNativeKeyboard.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

XcodeGen writes the `properties:` from `project.yml` into both files during generation.

- [ ] **Step 5: Write `LiveTextDocumentProxy.swift`**

```swift
import UIKit
import TextReplacement

/// Forwards `TextDocumentProxying` to the real `UITextDocumentProxy`.
///
/// This class is the only place UIKit meets the replacement logic, which is why
/// it holds no logic of its own.
final class LiveTextDocumentProxy: TextDocumentProxying {
    private let proxy: UITextDocumentProxy

    init(_ proxy: UITextDocumentProxy) {
        self.proxy = proxy
    }

    var selectedText: String? { proxy.selectedText }
    var documentContextBeforeInput: String? { proxy.documentContextBeforeInput }
    var documentContextAfterInput: String? { proxy.documentContextAfterInput }

    func insertText(_ text: String) { proxy.insertText(text) }
    func deleteBackward() { proxy.deleteBackward() }
}
```

- [ ] **Step 6: Write `KeyboardInputViewController.swift`**

```swift
import UIKit
import SwiftUI
import KeyboardUI

final class KeyboardInputViewController: UIInputViewController {
    private static let panelHeight: CGFloat = 290
    private static let promptDismissedKey = "keyboard.fullAccessPromptDismissed.v1"

    private var viewModel: KeyboardPanelViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        installHeightConstraint()
        installNextKeyboardButton()
        installPanel()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        viewModel?.textDidChange()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        viewModel?.selectionDidChange()
    }

    // MARK: - Setup

    private func installHeightConstraint() {
        let height = view.heightAnchor.constraint(equalToConstant: Self.panelHeight)
        // Below `.required` so the system can resize during rotation without
        // producing an unsatisfiable constraint.
        height.priority = .required - 1
        height.isActive = true
    }

    private func installNextKeyboardButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "globe"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)
        button.accessibilityIdentifier = "keyboardPanel.nextKeyboard"
        view.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            button.heightAnchor.constraint(equalToConstant: 32),
            button.widthAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func installPanel() {
        let services = KeyboardServices.make(hasFullAccess: hasFullAccess)
        let model = KeyboardPanelViewModel(
            proxy: LiveTextDocumentProxy(textDocumentProxy),
            enhancement: services.makeEnhancementViewModel(),
            availability: services.provider.availability,
            activePresets: services.presets.activePresets,
            hasFullAccess: hasFullAccess
        )
        viewModel = model

        let defaults = UserDefaults.standard
        let panel = KeyboardPanel(
            viewModel: model,
            isFullAccessPromptDismissed: defaults.bool(forKey: Self.promptDismissedKey),
            onDismissFullAccessPrompt: { defaults.set(true, forKey: Self.promptDismissedKey) }
        )

        let hosting = UIHostingController(rootView: panel)
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        hosting.view.backgroundColor = .clear
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -48),
        ])
        hosting.didMove(toParent: self)
    }
}
```

This references `KeyboardServices`, which Task 10 creates. The target will not compile until then — that is expected and is why Steps 7 and 8 only regenerate the project.

- [ ] **Step 7: Regenerate the project**

Run: `xcodegen generate`

Expected: `Created project at TalkNative.xcodeproj`.

- [ ] **Step 8: Commit**

```bash
git add project.yml TalkNativeKeyboard TalkNative.xcodeproj
git commit -m "feat(keyboard): add TalkNativeKeyboard target and proxy adapter"
```

---

### Task 10: Services factory with Full Access branching

**Files:**
- Create: `TalkNativeKeyboard/KeyboardServices.swift`

**Interfaces:**
- Consumes: `PresetStore` (PresetKit), `HistoryStore`/`HistorySchema`/`SavedVariant` (HistoryKit), `Enhancer`/`FoundationModelsProvider`/`LanguageModelProvider` (EnhancerCore), `EnhancementViewModel` (EnhancerUI)
- Produces: `@MainActor struct KeyboardServices` with `static func make(hasFullAccess: Bool) -> KeyboardServices`, `let presets: PresetStore`, `let history: HistoryStore?`, `let provider: any LanguageModelProvider`, `func makeEnhancementViewModel() -> EnhancementViewModel`

- [ ] **Step 1: Write `KeyboardServices.swift`**

```swift
import Foundation
import UIKit
import EnhancerCore
import PresetKit
import HistoryKit
import EnhancerUI

/// Mirrors `ExtensionServices` in `EnhanceExtension/ExtensionHostView.swift`,
/// but degrades when Full Access is off.
///
/// Without Full Access a keyboard extension cannot reach the App Group, so
/// custom presets and Recents are unavailable. The keyboard still works with
/// the eight built-in presets.
@MainActor
struct KeyboardServices {
    let presets: PresetStore
    let history: HistoryStore?
    let provider: any LanguageModelProvider

    static func make(hasFullAccess: Bool) -> KeyboardServices {
        let provider = FoundationModelsProvider()

        guard hasFullAccess else {
            let presets = PresetStore(defaults: .standard)
            presets.seedIfNeeded()
            return KeyboardServices(presets: presets, history: nil, provider: provider)
        }

        let appGroupID = "group.com.axveer.talknative"
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()

        let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let history = (try? HistorySchema.makeContainer(appGroupURL: containerURL))
            .map(HistoryStore.init(container:))

        return KeyboardServices(presets: presets, history: history, provider: provider)
    }

    func makeEnhancementViewModel() -> EnhancementViewModel {
        EnhancementViewModel(enhancer: Enhancer(provider: provider))
    }

    /// Record a completed run. No-op without Full Access.
    func record(inputText: String, variants: [SavedVariant]) {
        guard let history, !variants.isEmpty else { return }
        try? history.insert(
            inputText: inputText,
            variants: variants,
            deviceModelName: UIDevice.current.model
        )
    }
}
```

- [ ] **Step 2: Build the app**

```bash
xcodegen generate
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Run the no-network guard**

Run: `./scripts/no-network-check.sh`

Expected: `OK: no network API usage found`. If it fails on `TalkNativeKeyboard`, the guard does not yet cover it — that is added in Task 13, and a failure here means real network code was introduced.

- [ ] **Step 4: Commit**

```bash
git add TalkNativeKeyboard TalkNative.xcodeproj
git commit -m "feat(keyboard): add services factory with Full Access branching"
```

---

### Task 11: Record history on completion

**Files:**
- Modify: `TalkNativeKeyboard/KeyboardInputViewController.swift`

**Interfaces:**
- Consumes: `KeyboardServices.record(inputText:variants:)` (Task 10); `EnhancementViewModel.waitForCompletion()`, `VariantViewState` (EnhancerUI)
- Produces: no new public API

- [ ] **Step 1: Hold the services and record after completion**

In `KeyboardInputViewController`, add a stored property beside `viewModel`:

```swift
    private var services: KeyboardServices?
```

Then replace the body of `installPanel()`'s first three lines so the services are retained, and add the recording task. The updated `installPanel()` opening becomes:

```swift
    private func installPanel() {
        let services = KeyboardServices.make(hasFullAccess: hasFullAccess)
        self.services = services
        let enhancement = services.makeEnhancementViewModel()
        let model = KeyboardPanelViewModel(
            proxy: LiveTextDocumentProxy(textDocumentProxy),
            enhancement: enhancement,
            availability: services.provider.availability,
            activePresets: services.presets.activePresets,
            hasFullAccess: hasFullAccess
        )
        viewModel = model

        Task { [weak self] in
            await enhancement.waitForCompletion()
            self?.recordCompletedRun(from: enhancement)
        }
```

The remainder of `installPanel()` (the `defaults`, `panel`, and hosting-controller code) is unchanged.

- [ ] **Step 2: Add the recording method**

Add to `KeyboardInputViewController`, after `installPanel()`:

```swift
    private func recordCompletedRun(from enhancement: EnhancementViewModel) {
        let variants = enhancement.variantStates.compactMap { state -> SavedVariant? in
            guard case .completed = state.phase else { return nil }
            return SavedVariant(
                presetID: state.presetID,
                presetLabelSnapshot: state.presetLabel,
                outputText: state.text
            )
        }
        services?.record(inputText: enhancement.inputText, variants: variants)
    }
```

Add the imports this needs at the top of the file:

```swift
import EnhancerUI
import HistoryKit
```

- [ ] **Step 3: Build**

```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  CODE_SIGNING_ALLOWED=NO
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add TalkNativeKeyboard
git commit -m "feat(keyboard): record completed runs to history when Full Access is on"
```

---

## Phase 4 — Harness, CI, documentation

### Task 12: In-app panel harness and UI test

**Files:**
- Modify: `TalkNative/LaunchArguments.swift`
- Modify: `TalkNative/RootView.swift`
- Create: `TalkNativeUITests/KeyboardPanelUITests.swift`
- Modify: `project.yml`

**Interfaces:**
- Consumes: `KeyboardPanel`, `KeyboardPanelViewModel` (Phase 2); `StubTextDocumentProxy` (Phase 1); accessibility identifiers from Task 8
- Produces: launch argument `-showKeyboardPanel`

XCUITest cannot enable or drive an installed third-party keyboard — that needs a manual Settings toggle. This harness hosts the real `KeyboardPanel` inside the app over a stub proxy so the view, its states, and the undo strip are still covered.

- [ ] **Step 1: Add the launch argument**

Replace `TalkNative/LaunchArguments.swift` with:

```swift
import Foundation

enum LaunchArguments {
    static let useStubEnhancerFlag = "-useStubEnhancer"
    static let showKeyboardPanelFlag = "-showKeyboardPanel"
    static let prefillInputEnvKey = "TALKNATIVE_PREFILL_INPUT"

    static var useStubEnhancer: Bool {
        CommandLine.arguments.contains(useStubEnhancerFlag)
    }

    static var showKeyboardPanel: Bool {
        CommandLine.arguments.contains(showKeyboardPanelFlag)
    }

    static var prefilledInput: String? {
        ProcessInfo.processInfo.environment[prefillInputEnvKey]
    }
}
```

- [ ] **Step 2: Add the packages to the app and UI test targets**

In `project.yml`, add to the `TalkNative` target's `dependencies:`:

```yaml
      - package: KeyboardUI
      - package: TextReplacement
```

- [ ] **Step 3: Host the panel behind the flag**

Replace the `RootView` struct in `TalkNative/RootView.swift` (leaving `MainTabs` below it untouched) with:

```swift
import SwiftUI
import EnhancerCore
import EnhancerUI
import KeyboardUI
import TextReplacement

struct RootView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        if LaunchArguments.showKeyboardPanel {
            keyboardPanelHarness
        } else {
            switch services.provider.availability {
            case .available:
                MainTabs()
            case .unavailable(let reason):
                UnsupportedDeviceView(reason: reason)
            }
        }
    }

    /// XCUITest cannot enable or drive an installed third-party keyboard, so
    /// the real `KeyboardPanel` is hosted here over a stub proxy instead.
    private var keyboardPanelHarness: some View {
        KeyboardPanel(
            viewModel: KeyboardPanelViewModel(
                proxy: StubTextDocumentProxy(
                    before: "i has went to the store ",
                    selected: "and buyed some milks",
                    after: ""),
                enhancement: EnhancementViewModel(
                    enhancer: Enhancer(
                        provider: StubLanguageModelProvider(
                            scriptedChunks: ["I went to the store and bought some milk."]))),
                availability: .available,
                activePresets: services.presetStore.activePresets,
                hasFullAccess: true
            ),
            isFullAccessPromptDismissed: true,
            onDismissFullAccessPrompt: {}
        )
    }
}
```

Note `services.presetStore` — `AppServices` names the property `presetStore`, unlike `ExtensionServices`, which names it `presets`.

- [ ] **Step 4: Write the UI test**

`TalkNativeUITests/KeyboardPanelUITests.swift`:

```swift
import XCTest

final class KeyboardPanelUITests: XCTestCase {
    private func launchPanel() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-showKeyboardPanel"]
        app.launch()
        return app
    }

    func testVariantRowAppearsAndReplaceShowsUndo() {
        let app = launchPanel()

        let useButton = app.buttons["Use"].firstMatch
        XCTAssertTrue(useButton.waitForExistence(timeout: 10))

        useButton.tap()

        let confirmation = app.otherElements["keyboardPanel.replacedConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keyboardPanel.undo"].exists)
    }

    func testUndoReturnsToVariantList() {
        let app = launchPanel()

        let useButton = app.buttons["Use"].firstMatch
        XCTAssertTrue(useButton.waitForExistence(timeout: 10))
        useButton.tap()

        let undo = app.buttons["keyboardPanel.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()

        XCTAssertFalse(app.otherElements["keyboardPanel.replacedConfirmation"].exists)
        XCTAssertTrue(app.buttons["Use"].firstMatch.isEnabled)
    }
}
```

- [ ] **Step 5: Regenerate and run the UI tests**

```bash
xcodegen generate
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  -only-testing:TalkNativeUITests/KeyboardPanelUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **` with 2 tests passing.

- [ ] **Step 6: Run the full existing UI suite for regressions**

```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  -only-testing:TalkNativeUITests CODE_SIGNING_ALLOWED=NO
```

Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit**

```bash
git add project.yml TalkNative TalkNativeUITests TalkNative.xcodeproj
git commit -m "test(app): add in-app keyboard panel harness and UI tests"
```

---

### Task 13: CI guards and workflow

**Files:**
- Modify: `scripts/no-network-check.sh`
- Modify: `scripts/lint.sh`
- Modify: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: the packages and target from Tasks 2–11
- Produces: no code API

- [ ] **Step 1: Extend the no-network guard**

In `scripts/no-network-check.sh`, change line 5 from:

```bash
TARGETS=(Packages TalkNative EnhanceExtension)
```

to:

```bash
TARGETS=(Packages TalkNative EnhanceExtension TalkNativeKeyboard)
```

- [ ] **Step 2: Extend the lint script**

In `scripts/lint.sh`, change the final command from:

```bash
swift-format lint --recursive --strict \
  Packages TalkNative EnhanceExtension TalkNativeTests TalkNativeUITests DeviceSmokeTests
```

to:

```bash
swift-format lint --recursive --strict \
  Packages TalkNative EnhanceExtension TalkNativeKeyboard \
  TalkNativeTests TalkNativeUITests DeviceSmokeTests
```

- [ ] **Step 3: Add the package test steps to CI**

In `.github/workflows/ci.yml`, in the `packages` job, after the `Test EnhancerUI` step, add:

```yaml
      - name: Test TextReplacement
        run: swift test --package-path Packages/TextReplacement
      - name: Test KeyboardUI
        run: swift test --package-path Packages/KeyboardUI
```

- [ ] **Step 4: Run both guards locally**

```bash
./scripts/no-network-check.sh
./scripts/lint.sh
```

Expected: `OK: no network API usage found`, then lint exits 0. Fix any swift-format violations it reports before continuing.

- [ ] **Step 5: Run every package test suite**

```bash
for p in EnhancerCore PresetKit HistoryKit EnhancerUI TextReplacement KeyboardUI; do
  echo "== $p"
  swift test --package-path "Packages/$p" || exit 1
done
```

Expected: all six suites pass.

- [ ] **Step 6: Commit**

```bash
git add scripts .github/workflows/ci.yml
git commit -m "ci: cover TalkNativeKeyboard and the two new packages"
```

---

### Task 14: Documentation corrections

**Files:**
- Modify: `docs/superpowers/specs/2026-04-18-talknative-design.md` (lines 29 and 72)
- Modify: `README.md:68`
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/plans/2026-08-01-keyboard-extension-implementation.md` (this file — the manual checklist)

**Interfaces:**
- Consumes: nothing
- Produces: nothing

The v1 spec asserts a mechanism that does not exist. Leaving it in place means the next person re-derives the same dead end.

- [ ] **Step 1: Correct the v1 spec**

In `docs/superpowers/specs/2026-04-18-talknative-design.md`, replace line 29:

```markdown
3. **Action extension** (same target, Action activation rule). User selects text, taps "…" in the text menu → TalkNative. Result sheet shows variants; tapping one replaces the selected text in place via `NSExtensionContext.completeRequest`.
```

with:

```markdown
3. **Custom keyboard extension.** User selects text (or relies on what they just typed), switches to the TalkNative keyboard with the globe key, and taps a variant to replace the text in place via `UITextDocumentProxy`.

   > **Correction (2026-08-01):** this surface was originally specified as an Action extension replacing text via `NSExtensionContext.completeRequest`. That does not work — a returned `NSExtensionItem` is honoured only by hosts that implement `completionWithItemsHandler` on `UIActivityViewController`, which effectively no app does. See `2026-08-01-keyboard-extension-design.md`.
```

Then replace line 72:

```markdown
6. **User action.** Copy sets `UIPasteboard.general.string`. In the Action extension, tapping a variant calls `completeRequest(returningItems:)` for in-place replacement.
```

with:

```markdown
6. **User action.** Copy sets `UIPasteboard.general.string`. In the keyboard extension, tapping a variant issues `deleteBackward()` and `insertText(_:)` on the host's `UITextDocumentProxy` for in-place replacement, with a one-tap undo.
```

- [ ] **Step 2: Correct the README**

In `README.md`, replace line 68:

```markdown
The Action extension (in-place text replacement) is deferred to v1.1. The Share extension covers the primary invocation flow — see the spec section "Invocation surfaces" for intent.
```

with:

```markdown
### Keyboard extension

In-place rewriting is delivered by a custom keyboard rather than an Action extension — iOS gives an Action extension no way to write back into the host app's text field. Enable it under Settings → General → Keyboard → Keyboards → TalkNative.

The keyboard works immediately with the eight built-in presets. Granting **Allow Full Access** additionally makes your custom presets and Recents available to it; TalkNative has no network code at all, enforced in CI by `scripts/no-network-check.sh`.
```

- [ ] **Step 3: Update CLAUDE.md**

In `CLAUDE.md`, in the "Architecture" section's package list, append after the `EnhancerUI` bullet:

```markdown
- **TextReplacement** — leaf package holding `TextDocumentProxying`, the selection-first capture policy, and all replace/undo delete-count arithmetic. No dependencies, no UIKit; tests run on macOS. Delete counts are grapheme-cluster counts, never `utf16.count`.
- **KeyboardUI** — `KeyboardPanelState`, `KeyboardPanelViewModel`, and keyboard-density views. Depends on EnhancerCore + PresetKit + EnhancerUI + TextReplacement. Never imports UIKit.
```

In the same section, after the `AppServices` bullet, append:

```markdown
- **`TalkNativeKeyboard`** — custom keyboard extension (`com.apple.keyboard-service`). Holds only `KeyboardInputViewController`, `LiveTextDocumentProxy`, and `KeyboardServices`. Works without Full Access using built-in presets; Full Access unlocks App Group presets and history.
```

Finally, in the "Constraints" section, replace the last bullet:

```markdown
- The Action extension (in-place text replacement) is deferred to v1.1; only the Share extension ships in v1.
```

with:

```markdown
- In-place text replacement ships as a **custom keyboard extension**, not an Action extension. An Action extension cannot write back into a host app's text field on iOS — see `docs/superpowers/specs/2026-08-01-keyboard-extension-design.md`.
```

- [ ] **Step 4: Verify no stale references remain**

Run: `grep -rn "Action extension" README.md CLAUDE.md docs/superpowers/specs/2026-04-18-talknative-design.md`

Expected: the only hits are inside the correction notes added above, all of which explain why the Action extension does not work.

- [ ] **Step 5: Run the full check suite**

```bash
./scripts/lint.sh
./scripts/no-network-check.sh
for p in EnhancerCore PresetKit HistoryKit EnhancerUI TextReplacement KeyboardUI; do
  swift test --package-path "Packages/$p" || exit 1
done
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=latest" \
  -only-testing:TalkNativeTests CODE_SIGNING_ALLOWED=NO
```

Expected: everything green.

- [ ] **Step 6: Commit**

```bash
git add README.md CLAUDE.md docs
git commit -m "docs: replace Action extension with keyboard extension across docs"
```

- [ ] **Step 7: Run the manual device checklist**

Work through it on a physical Apple Intelligence-capable device and record the result in the PR description.

Items marked **[auto]** now have automated coverage through the scenario-driven `-showKeyboardPanel` harness (`TALKNATIVE_KEYBOARD_SCENARIO`) and the view-model/round-trip suites — see `TalkNativeUITests/KeyboardPanelUITests.swift` and `Packages/KeyboardUI/Tests`. The device run still validates them against real hosts, but a regression will fail in CI first. Items marked **[manual]** are system-level (Settings toggles, App Group state, jetsam, the globe key) and cannot be driven by XCUITest.

1. **[manual]** Enable the keyboard: Settings → General → Keyboard → Keyboards → Add New Keyboard → TalkNative.
2. **[auto: partial]** **Without Full Access:** open Notes, type a sentence, switch to the TalkNative keyboard. Confirm variants generate from built-in presets, no custom presets appear, and the Full Access prompt row is shown and dismisses permanently. *(Automated: prompt row shown without Full Access, absent once dismissed, variants still generate — `testFullAccessPromptShownWithoutFullAccess`, `testFullAccessPromptHiddenOnceDismissed`. Manual: that the presets are the built-ins and no custom ones leak — an App Group concern.)*
3. **[manual]** **Grant Full Access**, relaunch the keyboard. Confirm custom presets appear and a new entry lands in the app's Recents tab.
4. **[auto]** **Selection replace** in Messages, Notes, Safari, and Gmail: select a sentence, switch keyboards, tap a variant, confirm only the selection changed. *(`testVariantRowAppearsAndReplaceShowsUndo`; span integrity in the round-trip and view-model suites.)*
5. **[auto]** **Before-cursor replace** in the same four apps: type a sentence without selecting, tap a variant, confirm the sentence is replaced and preceding text is untouched. *(`testBeforeCursorTextReplaceShowsUndo`; `.contextBefore` arithmetic in the round-trip suite.)*
6. **[auto]** **Undo** in each app: confirm the original text returns exactly. *(`testUndoReturnsToVariantList`; `undoRestoresTheOriginalDocument`.)*
7. **[auto]** **Unicode:** type `caf\u{65}\u{301} \u{1F1FA}\u{1F1E6} \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}`, replace, then undo. Confirm no over-deletion into preceding text. *(`unicodeSelectionSurvivesReplaceAndUndo`; the `UnicodeCorpus` round-trip.)*
8. **[auto]** **Long selection:** select more than 2000 characters and confirm the "select up to 2000" message appears and **nothing is replaced**. *(`testLongSelectionShowsLimitMessageAndOffersNoReplacement`.)*
9. **[manual]** **Memory:** invoke the keyboard ten times in one session across apps. Confirm no termination. *(Produces the memory figure for the spec note — the one gate item still outstanding.)*
10. **[manual]** **Globe key:** confirm it switches away correctly from every panel state.

---

## Self-review notes

**Spec coverage.** Every section of `2026-08-01-keyboard-extension-design.md` maps to a task: the prerequisite spike → Task 1; `TextReplacement` components → Tasks 2–5; `KeyboardPanelState`/`ViewModel` → Tasks 6–7; panel views → Task 8; `project.yml`, entitlements, `KeyboardInputViewController`, `LiveTextDocumentProxy` → Task 9; `KeyboardServices` Full Access table → Task 10; history recording → Task 11; the `-showKeyboardPanel` harness and simulator gap → Task 12; CI changes → Task 13; documentation corrections and the manual checklist → Task 14.

**Naming consistency.** `TextCapture.capture` returns `CaptureOutcome` (not `CapturedText?`) in every task that calls it. `ReplacementPlan.replacing(_:with:)` and `.undoing(_:restoring:)` keep the same labels in Tasks 4, 5, and 7. `KeyboardPanelViewModel.select(variantText:)` is spelled identically in Tasks 7, 8, and 12.

**The two rules that carry the most risk**, both tested in Task 5 and re-tested at the view-model level in Task 7:
1. `.selection` → `deleteCount == 1`; `.contextBefore` → grapheme-cluster count, never `utf16.count`.
2. Undo re-sources the capture to `.contextBefore`, because the restored text is no longer selected.
