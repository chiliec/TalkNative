# Cloud Fallback Tier Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a BYOK Anthropic Claude Haiku 4.5 cloud tier, selected at boot on devices Apple excludes from Apple Intelligence (A15/A16 iPhones, non-Pro iPhone 15, older iPads), while leaving the on-device Foundation Models tier untouched on capable hardware.

**Architecture:** A new `CloudLanguageModelProvider` in `EnhancerCore` conforms to the existing `LanguageModelProvider` protocol and delegates to a tiny `AnthropicTransport` that speaks SSE over `URLSession`. A new leaf `CredentialStore` package stores the user's API key in the shared keychain-access-group so both the host app and Share extension read the same key. A `ProviderSelector` helper in the `TalkNative` target picks between `FoundationModelsProvider` and `CloudLanguageModelProvider` at boot and on scene-phase change. `CloudFallbackSettingsView` drives the BYOK setup flow.

**Tech Stack:** Swift 6, SwiftUI, Swift Concurrency (`actor`, `AsyncThrowingStream`), URLSession `bytes(for:)` SSE streaming, Security.framework Keychain (`SecItem*`), Swift Testing, XCTest for UI tests, XcodeGen, swift-format, GitHub Actions.

**Source spec:** `docs/superpowers/specs/2026-04-18-cloud-fallback-tier-design.md` (amends `2026-04-18-talknative-design.md`).

---

## File structure

### New files

**`Packages/CredentialStore/`** *(new SPM package, leaf — no deps on other project packages)*
- `Package.swift`
- `Sources/CredentialStore/CredentialStore.swift` — public struct, Keychain CRUD via `SecItem*`
- `Sources/CredentialStore/CredentialStoreError.swift` — `enum CredentialStoreError: Swift.Error`
- `Tests/CredentialStoreTests/CredentialStoreTests.swift` — round-trip + cross-instance read

**`Packages/EnhancerCore/Sources/EnhancerCore/`**
- `StreamingChatTransport.swift` — protocol + `StreamEvent` enum
- `SSEStream.swift` — internal SSE reader over `URLSession.AsyncBytes`
- `AnthropicTransport.swift` — concrete transport: request builder + error mapping + SSE decode
- `CloudLanguageModelProvider.swift` — `LanguageModelProvider` conformance

**`Packages/EnhancerCore/Tests/EnhancerCoreTests/`**
- `SSEStreamTests.swift`
- `AnthropicTransportTests.swift`
- `CloudLanguageModelProviderTests.swift`
- `URLProtocolMock.swift` — test helper: stubbable `URLProtocol` for HTTP + SSE fixtures

**`TalkNative/`**
- `ProviderSelector.swift`
- `Settings/CloudFallbackSettingsView.swift`
- `Settings/CloudFallbackViewModel.swift` — `@Observable` state for the settings screen
- `CloudDefaults.swift` — typed wrapper around App Group defaults keys (`cloud.optInAccepted`)

**`EnhanceExtension/`**
- No new files. `ExtensionHostView.swift` is modified in place.

**`TalkNativeTests/`**
- `ProviderSelectorTests.swift`

**`TalkNativeUITests/`**
- `CloudFallbackSettingsUITests.swift`
- `UnsupportedDeviceCloudCTAUITests.swift`

**`DeviceSmokeTests/`**
- `CloudProviderSmokeTests.swift`

**`.github/workflows/`**
- `cloud-smoke.yml` — new workflow, `workflow_dispatch` only, gated on secret

### Modified files

- `Packages/EnhancerCore/Sources/EnhancerCore/LanguageModelProvider.swift` — add `.apiKeyMissing`, `.networkUnavailable` cases
- `Packages/EnhancerCore/Sources/EnhancerCore/EnhancerError.swift` — update `userFacingMessage` to branch on new reasons
- `TalkNative/AppServices.swift` — async `makeProduction()`; hold `CredentialStore`; expose `rebootstrap()`
- `TalkNative/TalkNativeApp.swift` — await async bootstrap via `.task` with a loading view
- `TalkNative/RootView.swift` — observe `scenePhase`; call `rebootstrap()` on `.active`
- `TalkNative/UnsupportedDeviceView.swift` — add branches for `.apiKeyMissing` and `.networkUnavailable`
- `TalkNative/Settings/AboutView.swift` — two-paragraph tier-aware copy
- `TalkNative/Settings/PrivacyView.swift` — add "Cloud fallback" section
- `TalkNative/Tabs/SettingsTab.swift` — conditionally surface "Cloud fallback" row for ineligible devices
- `TalkNative/LaunchArguments.swift` — add `useStubCloud`, `forceAvailability` flags for UI tests
- `EnhanceExtension/ExtensionHostView.swift` — new availability branches; open host app via URL scheme
- `TalkNative/TalkNative.entitlements` — `keychain-access-groups`
- `EnhanceExtension/EnhanceExtension.entitlements` — `keychain-access-groups`
- `project.yml` — new package entry; new entitlement properties; URL scheme; test target deps
- `scripts/no-network-check.sh` — narrow to `FoundationModelsProvider.swift` + `EnhancerUI` only
- `.github/workflows/ci.yml` — add SPM test step for `CredentialStore`
- `README.md` — describe both tiers and BYOK setup flow
- `TalkNativeTests/AppFlowTests.swift` — one cloud-branch flow using `StubLanguageModelProvider`

---

## Task order and dependencies

Phases run top-to-bottom. Within a phase, tasks are independent unless noted.

- **Phase 1:** Foundations in packages (no app wiring)
- **Phase 2:** Availability reason + error messages
- **Phase 3:** HTTP transport + SSE + cloud provider
- **Phase 4:** App-level glue: selector, bootstrap, scene-phase
- **Phase 5:** Settings UI and unsupported-device UI
- **Phase 6:** Entitlements, URL scheme, project.yml
- **Phase 7:** Extension wiring
- **Phase 8:** UI tests
- **Phase 9:** Smoke test + CI
- **Phase 10:** Copy, docs, no-network guard narrowing
- **Phase 11:** Manual acceptance

---

## Phase 1 — CredentialStore package

### Task 1: Scaffold the CredentialStore package

**Files:**
- Create: `Packages/CredentialStore/Package.swift`
- Create: `Packages/CredentialStore/Sources/CredentialStore/CredentialStoreError.swift`
- Create: `Packages/CredentialStore/Sources/CredentialStore/CredentialStore.swift`
- Create: `Packages/CredentialStore/Tests/CredentialStoreTests/CredentialStoreTests.swift`

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "CredentialStore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "CredentialStore", targets: ["CredentialStore"])
    ],
    targets: [
        .target(name: "CredentialStore"),
        .testTarget(name: "CredentialStoreTests", dependencies: ["CredentialStore"]),
    ]
)
```

- [ ] **Step 2: Create the error type**

`Packages/CredentialStore/Sources/CredentialStore/CredentialStoreError.swift`:

```swift
import Foundation

public enum CredentialStoreError: Error, Equatable {
    case osError(OSStatus)
}
```

- [ ] **Step 3: Write the first failing test — round-trip save/load/clear**

`Packages/CredentialStore/Tests/CredentialStoreTests/CredentialStoreTests.swift`:

```swift
import Testing
import Foundation
@testable import CredentialStore

@Suite("CredentialStore", .enabled(if: CredentialStore.isKeychainAvailable))
struct CredentialStoreTests {

    private func makeStore() -> CredentialStore {
        CredentialStore(
            service: "com.axveer.talknative.tests.\(UUID().uuidString)",
            accessGroup: nil
        )
    }

    @Test func savesAndLoadsASingleKey() async throws {
        let store = makeStore()
        try await store.save("sk-ant-xxxx")
        let loaded = try await store.load()
        #expect(loaded == "sk-ant-xxxx")
        try await store.clear()
    }
}
```

- [ ] **Step 4: Run test to verify it fails (type does not exist yet)**

Run:
```bash
swift test --package-path Packages/CredentialStore
```

Expected: compile error on `CredentialStore` type not found.

- [ ] **Step 5: Implement CredentialStore with minimal surface**

`Packages/CredentialStore/Sources/CredentialStore/CredentialStore.swift`:

```swift
import Foundation
import Security

public struct CredentialStore: Sendable {
    public let service: String
    public let accessGroup: String?

    public init(service: String, accessGroup: String?) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public static var isKeychainAvailable: Bool {
        // Keychain works in simulator bundles and app processes, but not in
        // pure `swift test` CLI runs without a signed test host. A cheap
        // probe: attempt a no-op read.
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.axveer.credentialstore.probe",
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: false,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    public func save(_ key: String) async throws {
        let data = Data(key.utf8)
        var attrs: [String: Any] = baseQuery()
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        attrs[kSecValueData as String] = data

        // Try add; if duplicate, update.
        let addStatus = SecItemAdd(attrs as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let updateQuery = baseQuery()
            let updateAttrs: [String: Any] = [kSecValueData as String: data]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw CredentialStoreError.osError(updateStatus)
            }
        default:
            throw CredentialStoreError.osError(addStatus)
        }
    }

    public func load() async throws -> String? {
        var query: [String: Any] = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let string = String(data: data, encoding: .utf8) else { return nil }
            return string
        case errSecItemNotFound, errSecInteractionNotAllowed:
            return nil
        default:
            throw CredentialStoreError.osError(status)
        }
    }

    public func clear() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw CredentialStoreError.osError(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        if let accessGroup {
            q[kSecAttrAccessGroup as String] = accessGroup
        }
        return q
    }
}
```

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
swift test --package-path Packages/CredentialStore
```

Expected: PASS. (If Keychain is unavailable in the CLI, the suite is skipped — that's acceptable; CI runs it in the simulator later.)

- [ ] **Step 7: Commit**

```bash
git add Packages/CredentialStore
git commit -m "feat(credentials): add CredentialStore package with Keychain round-trip"
```

---

### Task 2: Expand CredentialStore tests — overwrite, clear, cross-instance

**Files:**
- Modify: `Packages/CredentialStore/Tests/CredentialStoreTests/CredentialStoreTests.swift`

- [ ] **Step 1: Add three more failing tests**

Append inside the `@Suite` struct:

```swift
@Test func overwriteReplacesValue() async throws {
    let store = makeStore()
    try await store.save("first")
    try await store.save("second")
    let loaded = try await store.load()
    #expect(loaded == "second")
    try await store.clear()
}

@Test func clearRemovesValue() async throws {
    let store = makeStore()
    try await store.save("x")
    try await store.clear()
    let loaded = try await store.load()
    #expect(loaded == nil)
}

@Test func secondInstanceSeesSameKey() async throws {
    let service = "com.axveer.talknative.tests.\(UUID().uuidString)"
    let a = CredentialStore(service: service, accessGroup: nil)
    let b = CredentialStore(service: service, accessGroup: nil)
    try await a.save("shared")
    let loaded = try await b.load()
    #expect(loaded == "shared")
    try await a.clear()
}

@Test func loadOnEmptyStoreReturnsNil() async throws {
    let store = makeStore()
    let loaded = try await store.load()
    #expect(loaded == nil)
}
```

- [ ] **Step 2: Run tests to confirm they all pass**

Run:
```bash
swift test --package-path Packages/CredentialStore
```

Expected: all tests PASS (or suite skipped on platforms without Keychain).

- [ ] **Step 3: Commit**

```bash
git add Packages/CredentialStore/Tests
git commit -m "test(credentials): cover overwrite, clear, cross-instance, empty-load"
```

---

## Phase 2 — Availability reason + error messages

### Task 3: Extend LanguageModelAvailability.Reason with new cases

**Files:**
- Modify: `Packages/EnhancerCore/Sources/EnhancerCore/LanguageModelProvider.swift`
- Modify: `Packages/EnhancerCore/Tests/EnhancerCoreTests/` (new file `LanguageModelAvailabilityTests.swift`)

- [ ] **Step 1: Write failing tests for new cases**

Create `Packages/EnhancerCore/Tests/EnhancerCoreTests/LanguageModelAvailabilityTests.swift`:

```swift
import Testing
import EnhancerCore

@Suite("LanguageModelAvailability reason cases")
struct LanguageModelAvailabilityTests {

    @Test func apiKeyMissingReasonExists() {
        let reason: LanguageModelAvailability.Reason = .apiKeyMissing
        #expect(reason == .apiKeyMissing)
    }

    @Test func networkUnavailableReasonExists() {
        let reason: LanguageModelAvailability.Reason = .networkUnavailable
        #expect(reason == .networkUnavailable)
    }

    @Test func newReasonsAreDistinctFromExisting() {
        #expect(LanguageModelAvailability.Reason.apiKeyMissing != .deviceNotEligible)
        #expect(LanguageModelAvailability.Reason.networkUnavailable != .modelNotReady)
        #expect(LanguageModelAvailability.Reason.apiKeyMissing != .networkUnavailable)
    }
}
```

- [ ] **Step 2: Run test to confirm compile failure**

Run:
```bash
swift test --package-path Packages/EnhancerCore
```

Expected: compile error — unknown case `.apiKeyMissing`.

- [ ] **Step 3: Add the cases**

Modify `Packages/EnhancerCore/Sources/EnhancerCore/LanguageModelProvider.swift` lines 7–12, replacing the `Reason` enum:

```swift
public enum Reason: Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case apiKeyMissing
    case networkUnavailable
    case other(String)
}
```

- [ ] **Step 4: Run tests to confirm they pass**

Run:
```bash
swift test --package-path Packages/EnhancerCore
```

Expected: PASS. Existing tests still pass (they don't exhaustively switch on `Reason`).

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore
git commit -m "feat(core): add .apiKeyMissing and .networkUnavailable availability reasons"
```

---

### Task 4: Update EnhancerError user-facing messages for new reasons

**Files:**
- Modify: `Packages/EnhancerCore/Sources/EnhancerCore/EnhancerError.swift`
- Modify: `Packages/EnhancerCore/Tests/EnhancerCoreTests/` (new file `EnhancerErrorMessageTests.swift`)

- [ ] **Step 1: Write failing tests for new messages**

Create `Packages/EnhancerCore/Tests/EnhancerCoreTests/EnhancerErrorMessageTests.swift`:

```swift
import Testing
import EnhancerCore

@Suite("EnhancerError user-facing messages")
struct EnhancerErrorMessageTests {

    @Test func apiKeyMissingHasDedicatedMessage() {
        let error = EnhancerError.modelUnavailable(.apiKeyMissing)
        #expect(error.userFacingMessage == "Cloud API key isn't set up. Open Settings to add one.")
    }

    @Test func networkUnavailableHasDedicatedMessage() {
        let error = EnhancerError.modelUnavailable(.networkUnavailable)
        #expect(error.userFacingMessage == "Cloud fallback needs a network connection.")
    }

    @Test func existingReasonsFallThroughToLegacyMessage() {
        let error = EnhancerError.modelUnavailable(.deviceNotEligible)
        #expect(error.userFacingMessage == "Apple Intelligence isn't available right now.")
    }
}
```

- [ ] **Step 2: Run tests to confirm they fail**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter EnhancerErrorMessageTests
```

Expected: two tests fail because `.apiKeyMissing` and `.networkUnavailable` collapse to the legacy message.

- [ ] **Step 3: Branch the message switch on reason**

Replace the `.modelUnavailable` arm of `userFacingMessage` in `Packages/EnhancerCore/Sources/EnhancerCore/EnhancerError.swift` (currently lines 23–24) with:

```swift
case .modelUnavailable(let reason):
    switch reason {
    case .apiKeyMissing:
        return "Cloud API key isn't set up. Open Settings to add one."
    case .networkUnavailable:
        return "Cloud fallback needs a network connection."
    case .deviceNotEligible,
         .appleIntelligenceNotEnabled,
         .modelNotReady,
         .other:
        return "Apple Intelligence isn't available right now."
    }
```

- [ ] **Step 4: Run tests to confirm PASS**

Run:
```bash
swift test --package-path Packages/EnhancerCore
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore
git commit -m "feat(core): tailor EnhancerError messages for new cloud reasons"
```

---

## Phase 3 — HTTP transport, SSE, cloud provider

### Task 5: Add StreamingChatTransport protocol and StreamEvent enum

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/StreamingChatTransport.swift`

*(No tests yet — this is pure protocol surface. Tests come via `AnthropicTransport` and `CloudLanguageModelProvider` in later tasks.)*

- [ ] **Step 1: Create the protocol and event enum**

`Packages/EnhancerCore/Sources/EnhancerCore/StreamingChatTransport.swift`:

```swift
import Foundation

public enum StreamEvent: Sendable, Equatable {
    case delta(String)
    case done
    case refusal(String)
}

public protocol StreamingChatTransport: Sendable {
    func streamText(
        system: String,
        user: String,
        model: String
    ) -> AsyncThrowingStream<StreamEvent, Error>
}
```

- [ ] **Step 2: Build the package to confirm it compiles**

Run:
```bash
swift build --package-path Packages/EnhancerCore
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Packages/EnhancerCore/Sources/EnhancerCore/StreamingChatTransport.swift
git commit -m "feat(core): add StreamingChatTransport protocol and StreamEvent"
```

---

### Task 6: Add SSEStream helper with tests

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/SSEStream.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/SSEStreamTests.swift`

- [ ] **Step 1: Write failing tests first**

Create `Packages/EnhancerCore/Tests/EnhancerCoreTests/SSEStreamTests.swift`:

```swift
import Testing
import Foundation
@testable import EnhancerCore

@Suite("SSEStream parsing")
struct SSEStreamTests {

    private func parse(_ raw: String) async throws -> [(event: String, data: String)] {
        let bytes = ByteSource(raw)
        var out: [(String, String)] = []
        for try await frame in SSEStream.frames(from: bytes) {
            out.append(frame)
        }
        return out
    }

    @Test func singleFrameWithEventAndData() async throws {
        let raw = "event: message\ndata: hello\n\n"
        let frames = try await parse(raw)
        #expect(frames.count == 1)
        #expect(frames[0].event == "message")
        #expect(frames[0].data == "hello")
    }

    @Test func multiLineDataIsJoinedWithNewlines() async throws {
        let raw = "event: message\ndata: line1\ndata: line2\n\n"
        let frames = try await parse(raw)
        #expect(frames.count == 1)
        #expect(frames[0].data == "line1\nline2")
    }

    @Test func missingEventDefaultsToEmptyString() async throws {
        let raw = "data: payload\n\n"
        let frames = try await parse(raw)
        #expect(frames.count == 1)
        #expect(frames[0].event == "")
        #expect(frames[0].data == "payload")
    }

    @Test func malformedLinesAreIgnored() async throws {
        let raw = "event: message\nbogus-line-without-colon\ndata: x\n\n"
        let frames = try await parse(raw)
        #expect(frames.count == 1)
        #expect(frames[0].data == "x")
    }

    @Test func multipleFrames() async throws {
        let raw = "event: a\ndata: 1\n\nevent: b\ndata: 2\n\n"
        let frames = try await parse(raw)
        #expect(frames.count == 2)
        #expect(frames[0].event == "a" && frames[0].data == "1")
        #expect(frames[1].event == "b" && frames[1].data == "2")
    }

    @Test func emptyInputYieldsNoFrames() async throws {
        let frames = try await parse("")
        #expect(frames.isEmpty)
    }

    @Test func frameWithoutTrailingBlankLineIsDropped() async throws {
        // SSE requires a blank line to terminate a frame.
        let raw = "event: message\ndata: incomplete"
        let frames = try await parse(raw)
        #expect(frames.isEmpty)
    }
}

/// Minimal async byte sequence over a string, used only by SSEStream tests.
struct ByteSource: AsyncSequence {
    typealias Element = UInt8
    let data: Data

    init(_ string: String) { self.data = Data(string.utf8) }

    func makeAsyncIterator() -> Iterator { Iterator(data: data) }

    struct Iterator: AsyncIteratorProtocol {
        var data: Data
        var index: Data.Index

        init(data: Data) { self.data = data; self.index = data.startIndex }

        mutating func next() async -> UInt8? {
            guard index < data.endIndex else { return nil }
            let byte = data[index]
            index = data.index(after: index)
            return byte
        }
    }
}
```

- [ ] **Step 2: Run tests to confirm compile failure**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter SSEStreamTests
```

Expected: compile error — `SSEStream` not found.

- [ ] **Step 3: Implement SSEStream**

Create `Packages/EnhancerCore/Sources/EnhancerCore/SSEStream.swift`:

```swift
import Foundation

/// Parses a stream of bytes as Server-Sent Events, yielding (event, data)
/// pairs per frame. Frames terminate on a blank line. `data:` lines with
/// the same event are concatenated with `\n`. Unrecognized lines are
/// ignored. Generic over any `AsyncSequence` of bytes so tests can feed
/// in-memory fixtures and production can feed `URLSession.AsyncBytes`.
enum SSEStream {

    static func frames<S>(from bytes: S) -> AsyncThrowingStream<(event: String, data: String), Error>
    where S: AsyncSequence, S.Element == UInt8, S: Sendable {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var lineBuffer: [UInt8] = []
                    var currentEvent = ""
                    var dataLines: [String] = []

                    for try await byte in bytes {
                        if byte == UInt8(ascii: "\n") {
                            let line = String(decoding: lineBuffer, as: UTF8.self)
                            lineBuffer.removeAll(keepingCapacity: true)

                            if line.isEmpty {
                                // Blank line → dispatch the accumulated frame.
                                if !dataLines.isEmpty || !currentEvent.isEmpty {
                                    continuation.yield((
                                        event: currentEvent,
                                        data: dataLines.joined(separator: "\n")
                                    ))
                                }
                                currentEvent = ""
                                dataLines.removeAll(keepingCapacity: true)
                            } else if let colon = line.firstIndex(of: ":") {
                                let field = String(line[..<colon])
                                var value = String(line[line.index(after: colon)...])
                                if value.first == " " { value.removeFirst() }
                                switch field {
                                case "event": currentEvent = value
                                case "data":  dataLines.append(value)
                                default:      break
                                }
                            } // lines without ':' are ignored
                        } else if byte != UInt8(ascii: "\r") {
                            lineBuffer.append(byte)
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 4: Run tests — all should pass**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter SSEStreamTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore
git commit -m "feat(core): add SSEStream with event/data frame parsing"
```

---

### Task 7: Add URLProtocolMock test helper for HTTP fixtures

**Files:**
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/URLProtocolMock.swift`

*(No tests here — this is a test helper. It's exercised in the next task.)*

- [ ] **Step 1: Create the helper**

```swift
import Foundation

/// URLProtocol that returns a canned status, headers, and streamed body
/// bytes. Install via a custom `URLSessionConfiguration.protocolClasses`.
/// The body is delivered in chunks with optional per-chunk delays so tests
/// can exercise mid-stream behavior (cancellation, drops).
final class URLProtocolMock: URLProtocol {

    struct Response: Sendable {
        var status: Int
        var headers: [String: String]
        var bodyChunks: [Data]
        var chunkDelay: Duration
        var midStreamError: URLError?
        init(
            status: Int = 200,
            headers: [String: String] = ["Content-Type": "text/event-stream"],
            bodyChunks: [Data] = [],
            chunkDelay: Duration = .zero,
            midStreamError: URLError? = nil
        ) {
            self.status = status
            self.headers = headers
            self.bodyChunks = bodyChunks
            self.chunkDelay = chunkDelay
            self.midStreamError = midStreamError
        }
    }

    /// Per-test handler: inspect the incoming URLRequest and return a Response.
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> Response)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = URLProtocolMock.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let response = handler(request)

        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)

        Task {
            for chunk in response.bodyChunks {
                if response.chunkDelay > .zero {
                    try? await Task.sleep(for: response.chunkDelay)
                }
                client?.urlProtocol(self, didLoad: chunk)
            }
            if let err = response.midStreamError {
                client?.urlProtocol(self, didFailWithError: err)
            } else {
                client?.urlProtocolDidFinishLoading(self)
            }
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolMock.self] + (config.protocolClasses ?? [])
        return URLSession(configuration: config)
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run:
```bash
swift build --package-path Packages/EnhancerCore --target EnhancerCoreTests
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Packages/EnhancerCore/Tests/EnhancerCoreTests/URLProtocolMock.swift
git commit -m "test(core): add URLProtocolMock for HTTP/SSE fixtures"
```

---

### Task 8: Implement AnthropicTransport happy path with tests

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/AnthropicTransport.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/AnthropicTransportTests.swift`

- [ ] **Step 1: Write failing happy-path test first**

Create `Packages/EnhancerCore/Tests/EnhancerCoreTests/AnthropicTransportTests.swift`:

```swift
import Testing
import Foundation
@testable import EnhancerCore

@Suite("AnthropicTransport")
struct AnthropicTransportTests {

    private let model = "claude-haiku-4-5-20251001"

    private func makeTransport(_ response: URLProtocolMock.Response,
                               capture: (@Sendable (URLRequest) -> Void)? = nil) -> AnthropicTransport {
        URLProtocolMock.handler = { request in
            capture?(request)
            return response
        }
        return AnthropicTransport(apiKey: "sk-ant-test", session: URLProtocolMock.makeSession())
    }

    @Test func happyPathEmitsDeltasThenDone() async throws {
        let body = """
        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"Hi"}}

        event: content_block_delta
        data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":" there"}}

        event: message_stop
        data: {"type":"message_stop"}

        """
        let transport = makeTransport(.init(bodyChunks: [Data(body.utf8)]))

        var events: [StreamEvent] = []
        for try await event in transport.streamText(system: "sys", user: "hey", model: model) {
            events.append(event)
        }
        #expect(events == [.delta("Hi"), .delta(" there"), .done])
    }

    @Test func requestHeadersAndBodyAreCorrect() async throws {
        actor Capture { var req: URLRequest?; func set(_ r: URLRequest) { req = r } }
        let capture = Capture()

        let body = """
        event: message_stop
        data: {"type":"message_stop"}

        """
        let transport = makeTransport(
            .init(bodyChunks: [Data(body.utf8)]),
            capture: { req in Task { await capture.set(req) } }
        )

        for try await _ in transport.streamText(system: "system prompt", user: "user prompt", model: model) {}

        let captured = await capture.req
        let request = try #require(captured)
        #expect(request.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-api-key") == "sk-ant-test")
        #expect(request.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")

        let bodyData = request.httpBody ?? request.httpBodyStream.map { stream in
            var data = Data(); stream.open(); defer { stream.close() }
            let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 4096)
            defer { buf.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buf, maxLength: 4096)
                if read <= 0 { break }
                data.append(buf, count: read)
            }
            return data
        } ?? Data()
        let json = try #require(try JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        #expect(json["model"] as? String == model)
        #expect(json["stream"] as? Bool == true)
        #expect(json["system"] as? String == "system prompt")
        #expect(json["max_tokens"] as? Int == 1024)
        let messages = try #require(json["messages"] as? [[String: Any]])
        #expect(messages.count == 1)
        #expect(messages[0]["role"] as? String == "user")
        #expect(messages[0]["content"] as? String == "user prompt")
    }
}
```

- [ ] **Step 2: Run tests — confirm compile failure**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter AnthropicTransportTests
```

Expected: compile error — `AnthropicTransport` not found.

- [ ] **Step 3: Implement AnthropicTransport**

Create `Packages/EnhancerCore/Sources/EnhancerCore/AnthropicTransport.swift`:

```swift
import Foundation

public struct AnthropicTransport: StreamingChatTransport {
    public let apiKey: String
    public let endpoint: URL
    public let session: URLSession

    public init(
        apiKey: String,
        endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.session = session
    }

    public func streamText(
        system: String,
        user: String,
        model: String
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let dataTask = Task<Void, Never> {
                do {
                    let request = try buildRequest(system: system, user: user, model: model)
                    let (bytes, response) = try await session.bytes(for: request)

                    if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
                        // Drain the body for possible JSON error detail; best-effort.
                        var body = Data()
                        for try await byte in bytes { body.append(byte) }
                        throw Self.mapHTTPError(status: http.statusCode, body: body)
                    }

                    for try await frame in SSEStream.frames(from: bytes) {
                        if let event = Self.decodeFrame(frame) {
                            continuation.yield(event)
                            if case .done = event { break }
                            if case .refusal = event { break }
                        }
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: EnhancerError.cancelled)
                } catch let urlErr as URLError where urlErr.code == .cancelled {
                    continuation.finish(throwing: EnhancerError.cancelled)
                } catch let urlErr as URLError {
                    continuation.finish(throwing: Self.mapURLError(urlErr))
                } catch let ee as EnhancerError {
                    continuation.finish(throwing: ee)
                } catch {
                    continuation.finish(throwing: EnhancerError.unknown(error))
                }
            }
            continuation.onTermination = { _ in dataTask.cancel() }
        }
    }

    private func buildRequest(system: String, user: String, model: String) throws -> URLRequest {
        var request = URLRequest(url: endpoint, timeoutInterval: 60)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "max_tokens": 1024,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    static func decodeFrame(_ frame: (event: String, data: String)) -> StreamEvent? {
        guard let data = frame.data.data(using: .utf8) else { return nil }
        switch frame.event {
        case "content_block_delta":
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let delta = obj["delta"] as? [String: Any],
                  delta["type"] as? String == "text_delta",
                  let text = delta["text"] as? String else { return nil }
            return .delta(text)
        case "message_delta":
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let delta = obj["delta"] as? [String: Any],
               delta["stop_reason"] as? String == "refusal" {
                return .refusal("refusal")
            }
            return nil
        case "message_stop":
            return .done
        default:
            return nil
        }
    }

    static func mapHTTPError(status: Int, body: Data) -> EnhancerError {
        switch status {
        case 401, 403:
            return .modelUnavailable(.apiKeyMissing)
        case 413:
            return .exceededContextWindow
        case 429, 529:
            return .rateLimited
        case 400:
            // Peek at Anthropic's error type; fall back to unknown.
            if let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let err = obj["error"] as? [String: Any],
               let message = err["message"] as? String {
                if message.localizedCaseInsensitiveContains("token") ||
                   message.localizedCaseInsensitiveContains("length") {
                    return .exceededContextWindow
                }
                if message.localizedCaseInsensitiveContains("safety") ||
                   message.localizedCaseInsensitiveContains("policy") {
                    return .guardrailViolation
                }
                return .unknown("HTTP 400: \(message)")
            }
            return .unknown("HTTP 400")
        case 500, 502, 503, 504:
            return .unknown("Server error \(status)")
        default:
            return .unknown("HTTP \(status)")
        }
    }

    static func mapURLError(_ err: URLError) -> EnhancerError {
        switch err.code {
        case .notConnectedToInternet, .dataNotAllowed, .cannotFindHost,
             .secureConnectionFailed, .cannotConnectToHost:
            return .modelUnavailable(.networkUnavailable)
        case .networkConnectionLost:
            return .unknown("Connection interrupted")
        default:
            return .unknown("URL error \(err.code.rawValue)")
        }
    }
}
```

- [ ] **Step 4: Run tests — happy path and request shape should now pass**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter AnthropicTransportTests
```

Expected: both tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore
git commit -m "feat(core): add AnthropicTransport with SSE streaming (happy path)"
```

---

### Task 9: AnthropicTransport — error mapping tests

**Files:**
- Modify: `Packages/EnhancerCore/Tests/EnhancerCoreTests/AnthropicTransportTests.swift`

- [ ] **Step 1: Append error-path tests**

Append inside the `@Suite` struct in `AnthropicTransportTests.swift`:

```swift
@Test func http401MapsToApiKeyMissing() async {
    let transport = makeTransport(.init(status: 401))
    await assertError(transport: transport, is: .modelUnavailable(.apiKeyMissing))
}

@Test func http403MapsToApiKeyMissing() async {
    let transport = makeTransport(.init(status: 403))
    await assertError(transport: transport, is: .modelUnavailable(.apiKeyMissing))
}

@Test func http429MapsToRateLimited() async {
    let transport = makeTransport(.init(status: 429))
    await assertError(transport: transport, is: .rateLimited)
}

@Test func http529MapsToRateLimited() async {
    let transport = makeTransport(.init(status: 529))
    await assertError(transport: transport, is: .rateLimited)
}

@Test func http413MapsToExceededContextWindow() async {
    let transport = makeTransport(.init(status: 413))
    await assertError(transport: transport, is: .exceededContextWindow)
}

@Test func http500MapsToUnknownRetryable() async {
    let transport = makeTransport(.init(status: 500))
    let error = await collectError(transport: transport)
    if case .unknown(let msg) = error ?? .cancelled {
        #expect(msg.contains("500"))
    } else {
        Issue.record("expected .unknown for 500; got \(String(describing: error))")
    }
}

@Test func refusalInMessageDeltaMapsToRefusalEvent() async throws {
    let body = """
    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"partial"}}

    event: message_delta
    data: {"type":"message_delta","delta":{"stop_reason":"refusal"}}

    """
    let transport = makeTransport(.init(bodyChunks: [Data(body.utf8)]))
    var events: [StreamEvent] = []
    for try await ev in transport.streamText(system: "s", user: "u", model: model) {
        events.append(ev)
    }
    #expect(events == [.delta("partial"), .refusal("refusal")])
}

@Test func offlineURLErrorMapsToNetworkUnavailable() async {
    URLProtocolMock.handler = { _ in
        .init(midStreamError: URLError(.notConnectedToInternet))
    }
    let transport = AnthropicTransport(apiKey: "sk-ant-test", session: URLProtocolMock.makeSession())
    await assertError(transport: transport, is: .modelUnavailable(.networkUnavailable))
}

@Test func cancellationMapsToCancelled() async {
    let body = """
    event: content_block_delta
    data: {"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"slow"}}

    """
    URLProtocolMock.handler = { _ in
        .init(bodyChunks: [Data(body.utf8), Data(body.utf8)], chunkDelay: .milliseconds(100))
    }
    let transport = AnthropicTransport(apiKey: "sk-ant-test", session: URLProtocolMock.makeSession())

    let task = Task {
        var count = 0
        do {
            for try await _ in transport.streamText(system: "s", user: "u", model: model) {
                count += 1
                if count == 1 { break }
            }
            return Result<Int, Error>.success(count)
        } catch {
            return Result<Int, Error>.failure(error)
        }
    }
    _ = await task.value
    // No assertion on count — we only need to confirm no crash / no hang.
}

// MARK: helpers
private func assertError(transport: AnthropicTransport, is expected: EnhancerError) async {
    let actual = await collectError(transport: transport)
    #expect(actual == expected, "got \(String(describing: actual))")
}

private func collectError(transport: AnthropicTransport) async -> EnhancerError? {
    do {
        for try await _ in transport.streamText(system: "s", user: "u", model: model) {}
        return nil
    } catch let e as EnhancerError {
        return e
    } catch {
        return .unknown(error)
    }
}
```

- [ ] **Step 2: Run tests — all should pass**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter AnthropicTransportTests
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Packages/EnhancerCore/Tests/EnhancerCoreTests/AnthropicTransportTests.swift
git commit -m "test(core): cover AnthropicTransport error mapping + cancellation"
```

---

### Task 10: Add CloudLanguageModelProvider with tests

**Files:**
- Create: `Packages/EnhancerCore/Sources/EnhancerCore/CloudLanguageModelProvider.swift`
- Create: `Packages/EnhancerCore/Tests/EnhancerCoreTests/CloudLanguageModelProviderTests.swift`

- [ ] **Step 1: Write failing tests first**

Create `Packages/EnhancerCore/Tests/EnhancerCoreTests/CloudLanguageModelProviderTests.swift`:

```swift
import Testing
import Foundation
@testable import EnhancerCore

@Suite("CloudLanguageModelProvider")
struct CloudLanguageModelProviderTests {

    struct FakeTransport: StreamingChatTransport {
        var events: [StreamEvent]
        var error: Error?

        func streamText(system: String, user: String, model: String)
            -> AsyncThrowingStream<StreamEvent, Error>
        {
            let events = events, error = error
            return AsyncThrowingStream { continuation in
                Task {
                    for event in events { continuation.yield(event) }
                    if let error { continuation.finish(throwing: error) }
                    else { continuation.finish() }
                }
            }
        }
    }

    @Test func availabilityIsAvailableWhenExplicitlySet() {
        let p = CloudLanguageModelProvider(
            transport: FakeTransport(events: []),
            model: "m",
            availability: .available
        )
        #expect(p.availability == .available)
    }

    @Test func availabilityIsApiKeyMissingWhenExplicitlySet() {
        let p = CloudLanguageModelProvider(
            transport: FakeTransport(events: []),
            model: "m",
            availability: .unavailable(.apiKeyMissing)
        )
        #expect(p.availability == .unavailable(.apiKeyMissing))
    }

    @Test func streamForwardsDeltaEventsAsStrings() async throws {
        let transport = FakeTransport(events: [.delta("Hi"), .delta(" there"), .done])
        let p = CloudLanguageModelProvider(transport: transport, model: "m", availability: .available)

        var collected = ""
        for try await chunk in p.stream(instructions: "sys", prompt: "hi") {
            collected += chunk
        }
        #expect(collected == "Hi there")
    }

    @Test func streamThrowsGuardrailOnRefusalEvent() async {
        let transport = FakeTransport(events: [.delta("partial"), .refusal("refusal")])
        let p = CloudLanguageModelProvider(transport: transport, model: "m", availability: .available)

        var caught: EnhancerError?
        do {
            for try await _ in p.stream(instructions: "sys", prompt: "hi") {}
        } catch let e as EnhancerError {
            caught = e
        } catch {
            Issue.record("expected EnhancerError, got \(error)")
        }
        #expect(caught == .guardrailViolation)
    }

    @Test func streamPropagatesTransportErrors() async {
        struct Boom: Error, Equatable {}
        let transport = FakeTransport(events: [.delta("x")], error: EnhancerError.rateLimited)
        let p = CloudLanguageModelProvider(transport: transport, model: "m", availability: .available)

        var caught: EnhancerError?
        do {
            for try await _ in p.stream(instructions: "sys", prompt: "hi") {}
        } catch let e as EnhancerError {
            caught = e
        } catch {
            Issue.record("expected EnhancerError")
        }
        #expect(caught == .rateLimited)
    }
}
```

- [ ] **Step 2: Run tests — confirm compile failure**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter CloudLanguageModelProviderTests
```

Expected: compile error.

- [ ] **Step 3: Implement CloudLanguageModelProvider**

Create `Packages/EnhancerCore/Sources/EnhancerCore/CloudLanguageModelProvider.swift`:

```swift
import Foundation

public struct CloudLanguageModelProvider: LanguageModelProvider {
    public let availability: LanguageModelAvailability
    private let transport: any StreamingChatTransport
    private let model: String

    public init(
        transport: any StreamingChatTransport,
        model: String,
        availability: LanguageModelAvailability
    ) {
        self.transport = transport
        self.model = model
        self.availability = availability
    }

    public func stream(instructions: String, prompt: String) -> AsyncThrowingStream<String, Error> {
        let transport = self.transport
        let model = self.model
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await event in transport.streamText(
                        system: instructions, user: prompt, model: model
                    ) {
                        switch event {
                        case .delta(let text):
                            continuation.yield(text)
                        case .done:
                            continuation.finish()
                            return
                        case .refusal:
                            continuation.finish(throwing: EnhancerError.guardrailViolation)
                            return
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
```

- [ ] **Step 4: Run tests — all should pass**

Run:
```bash
swift test --package-path Packages/EnhancerCore --filter CloudLanguageModelProviderTests
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Packages/EnhancerCore
git commit -m "feat(core): add CloudLanguageModelProvider over StreamingChatTransport"
```

---

### Task 11: Phase-1-through-3 regression check

- [ ] **Step 1: Run the whole EnhancerCore package test suite**

Run:
```bash
swift test --package-path Packages/EnhancerCore
```

Expected: all tests PASS. No existing behavior should have regressed.

- [ ] **Step 2: Run CredentialStore tests**

Run:
```bash
swift test --package-path Packages/CredentialStore
```

Expected: PASS or skip (depending on Keychain availability in the CLI).

- [ ] **Step 3: No commit** (nothing to commit; this is a gate step).

---

## Phase 4 — App-level glue: selector, bootstrap, scene-phase

### Task 12: Wire CredentialStore + EnhancerCore into project.yml

**Files:**
- Modify: `project.yml`

Xcode project must know about the new `CredentialStore` package and the new files in `EnhancerCore` before `xcodegen generate` can produce a buildable project. Do this before any app-level code changes.

- [ ] **Step 1: Add CredentialStore to packages map**

Modify `project.yml` lines 14–18 to add one entry:

```yaml
packages:
  EnhancerCore:   { path: Packages/EnhancerCore }
  PresetKit:      { path: Packages/PresetKit }
  HistoryKit:     { path: Packages/HistoryKit }
  EnhancerUI:     { path: Packages/EnhancerUI }
  CredentialStore: { path: Packages/CredentialStore }
```

- [ ] **Step 2: Add CredentialStore as a dependency of TalkNative and EnhanceExtension targets**

In the `targets.TalkNative.dependencies` list, append:

```yaml
      - package: CredentialStore
```

In the `targets.EnhanceExtension.dependencies` list, append:

```yaml
      - package: CredentialStore
```

- [ ] **Step 3: Regenerate the Xcode project**

Run:
```bash
xcodegen generate
```

Expected: project regenerates without error.

- [ ] **Step 4: Build the app target to confirm linkage**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

- [ ] **Step 5: Commit**

```bash
git add project.yml TalkNative.xcodeproj
git commit -m "build: wire CredentialStore package into Xcode project"
```

---

### Task 13: Add CloudDefaults wrapper for App Group opt-in flag

**Files:**
- Create: `TalkNative/CloudDefaults.swift`

*(No test — thin wrapper over UserDefaults. Exercised by ProviderSelectorTests in Task 14.)*

- [ ] **Step 1: Create the wrapper**

```swift
import Foundation

enum CloudDefaults {
    static let optInAcceptedKey = "cloud.optInAccepted"

    static func optInAccepted(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: optInAcceptedKey)
    }

    static func setOptInAccepted(_ value: Bool, in defaults: UserDefaults) {
        defaults.set(value, forKey: optInAcceptedKey)
    }
}
```

- [ ] **Step 2: Commit (bundled with Task 14's commit; skip now)**

---

### Task 14: Add ProviderSelector with tests

**Files:**
- Create: `TalkNative/ProviderSelector.swift`
- Create: `TalkNativeTests/ProviderSelectorTests.swift`

The selector needs to be testable without invoking the real `SystemLanguageModel`. Abstract the availability source behind a tiny protocol.

- [ ] **Step 1: Write failing tests**

Create `TalkNativeTests/ProviderSelectorTests.swift`:

```swift
import Testing
import Foundation
@testable import TalkNative
import EnhancerCore
import CredentialStore

@MainActor
@Suite("ProviderSelector")
struct ProviderSelectorTests {

    private func tempDefaults() -> UserDefaults {
        UserDefaults(suiteName: "selector.\(UUID().uuidString)")!
    }

    private func store(withKey key: String?) -> CredentialStore {
        let service = "test.\(UUID().uuidString)"
        let store = CredentialStore(service: service, accessGroup: nil)
        if let key {
            Task { try? await store.save(key) }
        }
        return store
    }

    @Test func foundationAvailableReturnsFoundationProvider() async {
        let provider = await ProviderSelector.resolve(
            availabilityProvider: StubAvailability(.available),
            credentials: store(withKey: nil),
            defaults: tempDefaults()
        )
        #expect(provider is FoundationModelsProvider)
    }

    @Test func ineligibleWithKeyAndOptInReturnsAvailableCloud() async throws {
        let store = CredentialStore(service: "t.\(UUID())", accessGroup: nil)
        try await store.save("sk-ant-xxxx")
        let defaults = tempDefaults()
        CloudDefaults.setOptInAccepted(true, in: defaults)

        let provider = await ProviderSelector.resolve(
            availabilityProvider: StubAvailability(.unavailable(.deviceNotEligible)),
            credentials: store,
            defaults: defaults
        )
        #expect(provider is CloudLanguageModelProvider)
        #expect(provider.availability == .available)
        try await store.clear()
    }

    @Test func ineligibleWithKeyButNoOptInReturnsApiKeyMissing() async throws {
        let store = CredentialStore(service: "t.\(UUID())", accessGroup: nil)
        try await store.save("sk-ant-xxxx")

        let provider = await ProviderSelector.resolve(
            availabilityProvider: StubAvailability(.unavailable(.deviceNotEligible)),
            credentials: store,
            defaults: tempDefaults()
        )
        #expect(provider.availability == .unavailable(.apiKeyMissing))
        try await store.clear()
    }

    @Test func ineligibleWithNoKeyReturnsApiKeyMissing() async {
        let provider = await ProviderSelector.resolve(
            availabilityProvider: StubAvailability(.unavailable(.deviceNotEligible)),
            credentials: store(withKey: nil),
            defaults: tempDefaults()
        )
        #expect(provider.availability == .unavailable(.apiKeyMissing))
    }

    @Test func appleIntelligenceNotEnabledReturnsFoundationProvider() async {
        let provider = await ProviderSelector.resolve(
            availabilityProvider: StubAvailability(.unavailable(.appleIntelligenceNotEnabled)),
            credentials: store(withKey: nil),
            defaults: tempDefaults()
        )
        #expect(provider is FoundationModelsProvider)
    }

    @Test func modelNotReadyReturnsFoundationProvider() async {
        let provider = await ProviderSelector.resolve(
            availabilityProvider: StubAvailability(.unavailable(.modelNotReady)),
            credentials: store(withKey: nil),
            defaults: tempDefaults()
        )
        #expect(provider is FoundationModelsProvider)
    }
}

private struct StubAvailability: SystemAvailabilityProvider {
    let value: LanguageModelAvailability
    init(_ v: LanguageModelAvailability) { self.value = v }
    var availability: LanguageModelAvailability { value }
}
```

- [ ] **Step 2: Run tests — confirm compile failure**

Run (in Xcode project):
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeTests/ProviderSelectorTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: compile errors — `ProviderSelector`, `SystemAvailabilityProvider` not found.

- [ ] **Step 3: Implement ProviderSelector and the availability seam**

Create `TalkNative/ProviderSelector.swift`:

```swift
import Foundation
import EnhancerCore
import CredentialStore

protocol SystemAvailabilityProvider: Sendable {
    var availability: LanguageModelAvailability { get }
}

extension FoundationModelsProvider: SystemAvailabilityProvider {}

@MainActor
enum ProviderSelector {

    static let model = "claude-haiku-4-5-20251001"

    static func resolve(
        availabilityProvider: any SystemAvailabilityProvider = FoundationModelsProvider(),
        credentials: CredentialStore,
        defaults: UserDefaults
    ) async -> any LanguageModelProvider {
        let availability = availabilityProvider.availability
        switch availability {
        case .available:
            return FoundationModelsProvider()
        case .unavailable(.deviceNotEligible):
            return await resolveCloud(credentials: credentials, defaults: defaults)
        case .unavailable:
            // For .appleIntelligenceNotEnabled, .modelNotReady, .other — keep
            // the Foundation path so the UI surfaces the correct remediation.
            return FoundationModelsProvider()
        }
    }

    private static func resolveCloud(
        credentials: CredentialStore,
        defaults: UserDefaults
    ) async -> any LanguageModelProvider {
        let key = (try? await credentials.load()) ?? nil
        let optIn = CloudDefaults.optInAccepted(in: defaults)
        let availability: LanguageModelAvailability
        let apiKey: String
        if let key, !key.isEmpty, optIn {
            availability = .available
            apiKey = key
        } else {
            availability = .unavailable(.apiKeyMissing)
            apiKey = key ?? ""
        }
        let transport = AnthropicTransport(apiKey: apiKey)
        return CloudLanguageModelProvider(
            transport: transport,
            model: model,
            availability: availability
        )
    }
}
```

- [ ] **Step 4: Run tests — all should pass**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeTests/ProviderSelectorTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add TalkNative/CloudDefaults.swift TalkNative/ProviderSelector.swift \
        TalkNativeTests/ProviderSelectorTests.swift
git commit -m "feat(app): add ProviderSelector and CloudDefaults helper"
```

---

### Task 15: Async AppServices.makeProduction + rebootstrap

**Files:**
- Modify: `TalkNative/AppServices.swift`

- [ ] **Step 1: Rewrite `AppServices` to expose async bootstrap and a rebootstrap method**

Replace the existing file contents with:

```swift
import Foundation
import SwiftData
import Observation
import EnhancerCore
import PresetKit
import HistoryKit
import CredentialStore

@Observable
@MainActor
final class AppServices {
    let presetStore: PresetStore
    let historyStore: HistoryStore
    let credentials: CredentialStore
    private(set) var enhancer: Enhancer
    private(set) var provider: any LanguageModelProvider

    init(
        presetStore: PresetStore,
        historyStore: HistoryStore,
        enhancer: Enhancer,
        provider: any LanguageModelProvider,
        credentials: CredentialStore
    ) {
        self.presetStore = presetStore
        self.historyStore = historyStore
        self.enhancer = enhancer
        self.provider = provider
        self.credentials = credentials
    }

    static func makeProduction() async -> AppServices {
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

        let credentials = CredentialStore(
            service: "com.axveer.talknative.cloud",
            accessGroup: AppGroup.keychainAccessGroup
        )
        let provider = await ProviderSelector.resolve(
            credentials: credentials,
            defaults: defaults
        )
        let enhancer = Enhancer(provider: provider)

        return AppServices(
            presetStore: presetStore,
            historyStore: historyStore,
            enhancer: enhancer,
            provider: provider,
            credentials: credentials
        )
    }

    /// Re-resolves the provider without rebuilding stores. Called when the
    /// app returns to the foreground or when cloud credentials change.
    func rebootstrap() async {
        let defaults = AppGroup.sharedDefaults
        let fresh = await ProviderSelector.resolve(
            credentials: credentials,
            defaults: defaults
        )
        provider = fresh
        enhancer = Enhancer(provider: fresh)
    }
}

extension AppServices {
    static func makeStubbed() -> AppServices {
        let defaults = UserDefaults(suiteName: "ui-test.\(UUID().uuidString)")!
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()
        let container = (try? HistorySchema.makeContainer(appGroupURL: nil))!
        let historyStore = HistoryStore(container: container)
        let provider = StubLanguageModelProvider(scriptedChunks: ["Hi ", "there"])
        let enhancer = Enhancer(provider: provider)
        let credentials = CredentialStore(
            service: "ui-test.\(UUID().uuidString)",
            accessGroup: nil
        )
        return AppServices(
            presetStore: presetStore,
            historyStore: historyStore,
            enhancer: enhancer,
            provider: provider,
            credentials: credentials
        )
    }
}
```

- [ ] **Step 2: Add keychain-access-group helper to AppGroup**

Modify `TalkNative/AppGroup.swift` — append a static var:

```swift
public enum AppGroup {
    public static let identifier = "group.com.axveer.talknative"
    public static let keychainAccessGroup = "$(AppIdentifierPrefix)group.com.axveer.talknative"

    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    public static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}
```

*(The `$(AppIdentifierPrefix)` macro is expanded by Keychain Services at runtime — no literal team ID in source.)*

- [ ] **Step 3: Build to verify**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds. Call sites of `AppServices.makeProduction` will still be sync — we update them in the next task.

- [ ] **Step 4: Commit**

```bash
git add TalkNative/AppServices.swift TalkNative/AppGroup.swift
git commit -m "feat(app): async AppServices bootstrap with CredentialStore"
```

---

### Task 16: Update TalkNativeApp to await async bootstrap + loading view

**Files:**
- Modify: `TalkNative/TalkNativeApp.swift`

- [ ] **Step 1: Rewrite TalkNativeApp to show a splash during async bootstrap**

Replace with:

```swift
import SwiftUI

@main
struct TalkNativeApp: App {
    @State private var services: AppServices?

    var body: some Scene {
        WindowGroup {
            Group {
                if let services {
                    RootView()
                        .environment(services)
                } else {
                    BootSplash()
                        .task {
                            if LaunchArguments.useStubEnhancer {
                                services = AppServices.makeStubbed()
                            } else {
                                services = await AppServices.makeProduction()
                            }
                        }
                }
            }
        }
    }
}

private struct BootSplash: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Starting TalkNative…")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: build succeeds.

- [ ] **Step 3: Run existing UI tests to confirm no regression**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all existing UI tests PASS. The stub path is sync, so no splash delay affects them.

- [ ] **Step 4: Commit**

```bash
git add TalkNative/TalkNativeApp.swift
git commit -m "feat(app): await async bootstrap with splash screen"
```

---

### Task 17: Scene-phase rebootstrap in RootView

**Files:**
- Modify: `TalkNative/RootView.swift`

- [ ] **Step 1: Add scene-phase observation**

Replace with:

```swift
import SwiftUI
import EnhancerCore

struct RootView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await services.rebootstrap() }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
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

- [ ] **Step 2: Build + run UI tests**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add TalkNative/RootView.swift
git commit -m "feat(app): rebootstrap provider on scene-phase active"
```

---

## Phase 5 — Settings UI and unsupported-device UI

### Task 18: Add CloudFallbackViewModel

**Files:**
- Create: `TalkNative/Settings/CloudFallbackViewModel.swift`

*(The VM holds state, reads/writes the credential store and App Group defaults, and runs test-connection. No unit tests here — covered implicitly by UI tests in Phase 8 and manually via TestConnection.)*

- [ ] **Step 1: Create the view model**

```swift
import Foundation
import Observation
import CredentialStore
import EnhancerCore

@Observable
@MainActor
final class CloudFallbackViewModel {
    enum TestResult: Equatable {
        case idle
        case running
        case success
        case failure(String)
    }

    var pendingKey: String = ""
    var savedKeyPreview: String? = nil           // "…abcd" or nil
    var showInvalidPrefixWarning: Bool = false
    var optInAccepted: Bool = false
    var testResult: TestResult = .idle

    private let credentials: CredentialStore
    private let defaults: UserDefaults
    private let services: AppServices

    init(credentials: CredentialStore, defaults: UserDefaults, services: AppServices) {
        self.credentials = credentials
        self.defaults = defaults
        self.services = services
    }

    func load() async {
        let key = (try? await credentials.load()) ?? nil
        savedKeyPreview = key.map { Self.mask($0) }
        optInAccepted = CloudDefaults.optInAccepted(in: defaults)
    }

    func pendingKeyChanged(_ newValue: String) {
        pendingKey = newValue
        showInvalidPrefixWarning = !newValue.isEmpty && !newValue.hasPrefix("sk-ant-")
    }

    func save() async {
        let key = pendingKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        try? await credentials.save(key)
        pendingKey = ""
        savedKeyPreview = Self.mask(key)
        showInvalidPrefixWarning = false
        await services.rebootstrap()
    }

    func clear() async {
        try? await credentials.clear()
        savedKeyPreview = nil
        pendingKey = ""
        testResult = .idle
        await services.rebootstrap()
    }

    func setOptIn(_ value: Bool) async {
        CloudDefaults.setOptInAccepted(value, in: defaults)
        optInAccepted = value
        await services.rebootstrap()
    }

    func testConnection() async {
        guard let key = try? await credentials.load(), let key else {
            testResult = .failure("No key saved.")
            return
        }
        testResult = .running
        let transport = AnthropicTransport(apiKey: key)
        do {
            let stream = transport.streamText(
                system: "Respond with a single letter.",
                user: "ok",
                model: ProviderSelector.model
            )
            // Consume until first event (delta or done); success if we get that far.
            for try await _ in stream { break }
            testResult = .success
        } catch let e as EnhancerError {
            testResult = .failure(e.userFacingMessage)
        } catch {
            testResult = .failure(String(describing: error))
        }
    }

    private static func mask(_ key: String) -> String {
        let suffix = key.suffix(4)
        return "…\(suffix)"
    }
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add TalkNative/Settings/CloudFallbackViewModel.swift
git commit -m "feat(app): add CloudFallbackViewModel"
```

---

### Task 19: Add CloudFallbackSettingsView

**Files:**
- Create: `TalkNative/Settings/CloudFallbackSettingsView.swift`

- [ ] **Step 1: Create the SwiftUI view**

```swift
import SwiftUI
import EnhancerCore

struct CloudFallbackSettingsView: View {
    @Environment(AppServices.self) private var services
    @State private var viewModel: CloudFallbackViewModel?

    var body: some View {
        Form {
            if let vm = viewModel {
                statusSection(vm: vm)
                keySection(vm: vm)
                providerSection
                disclosureSection(vm: vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Cloud fallback")
        .task {
            if viewModel == nil {
                let vm = CloudFallbackViewModel(
                    credentials: services.credentials,
                    defaults: AppGroup.sharedDefaults,
                    services: services
                )
                await vm.load()
                viewModel = vm
            }
        }
    }

    @ViewBuilder
    private func statusSection(vm: CloudFallbackViewModel) -> some View {
        Section("Status") {
            HStack {
                Text(vm.savedKeyPreview == nil ? "No key" : "Key saved")
                Spacer()
                if let preview = vm.savedKeyPreview {
                    Text(preview).foregroundStyle(.secondary).monospaced()
                }
            }
            Button("Test connection") {
                Task { await vm.testConnection() }
            }
            .accessibilityIdentifier("cloud.test")
            .disabled(vm.savedKeyPreview == nil)

            switch vm.testResult {
            case .idle:
                EmptyView()
            case .running:
                ProgressView("Testing…")
            case .success:
                Label("Connection OK", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .failure(let message):
                Label(message, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func keySection(vm: CloudFallbackViewModel) -> some View {
        @Bindable var bindable = vm
        Section("API key") {
            SecureField("sk-ant-…", text: $bindable.pendingKey)
                .accessibilityIdentifier("cloud.key.field")
                .textContentType(.password)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .onChange(of: bindable.pendingKey) { _, new in
                    vm.pendingKeyChanged(new)
                }

            if vm.showInvalidPrefixWarning {
                Text("Doesn't look like an Anthropic key (expected sk-ant-…). You can still save it.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Save") {
                    Task { await vm.save() }
                }
                .accessibilityIdentifier("cloud.save")
                .disabled(vm.pendingKey.isEmpty)

                Spacer()

                Button("Clear", role: .destructive) {
                    Task { await vm.clear() }
                }
                .accessibilityIdentifier("cloud.clear")
                .disabled(vm.savedKeyPreview == nil)
            }
        }
    }

    @ViewBuilder
    private var providerSection: some View {
        Section("Provider") {
            Picker("Provider", selection: .constant(CloudProvider.anthropic)) {
                Text("Anthropic Claude Haiku 4.5").tag(CloudProvider.anthropic)
                Text("OpenAI (coming soon)").tag(CloudProvider.openai).disabled(true)
                Text("Google Gemini (coming soon)").tag(CloudProvider.gemini).disabled(true)
            }
            .accessibilityIdentifier("cloud.provider")
            .pickerStyle(.menu)
        }
    }

    @ViewBuilder
    private func disclosureSection(vm: CloudFallbackViewModel) -> some View {
        @Bindable var bindable = vm
        Section("Disclosure") {
            Text(
                "Using cloud fallback sends the text you enhance to Anthropic's servers over HTTPS. Nothing else is sent. Your key is stored in the device keychain and never leaves the device except as an authentication header to Anthropic."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Text("Apple Intelligence users stay on-device.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Toggle("I understand and opt in", isOn: Binding(
                get: { vm.optInAccepted },
                set: { new in Task { await vm.setOptIn(new) } }
            ))
            .accessibilityIdentifier("cloud.optIn")
        }
    }
}

enum CloudProvider: Hashable {
    case anthropic
    case openai
    case gemini
}
```

- [ ] **Step 2: Build to verify**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add TalkNative/Settings/CloudFallbackSettingsView.swift
git commit -m "feat(app): add CloudFallbackSettingsView"
```

---

### Task 20: Surface Cloud fallback row in SettingsTab

**Files:**
- Modify: `TalkNative/Tabs/SettingsTab.swift`

- [ ] **Step 1: Add a Cloud fallback section visible only on ineligible devices**

Modify `TalkNative/Tabs/SettingsTab.swift` — insert a new `Section` after the `History` section (around line 18), before `About`:

```swift
if isIneligibleDevice {
    Section("Cloud fallback") {
        NavigationLink("Cloud fallback") { CloudFallbackSettingsView() }
    }
}
```

Add a computed property to `SettingsTab` (outside `var body`):

```swift
private var isIneligibleDevice: Bool {
    if case .unavailable(.deviceNotEligible) = EnhancerCore.FoundationModelsProvider().availability {
        return true
    }
    // Also surface the section when the current provider is already cloud,
    // so users can see their setup regardless of transient state.
    if services.provider is EnhancerCore.CloudLanguageModelProvider {
        return true
    }
    return false
}
```

Add `import EnhancerCore` at the top if not present.

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add TalkNative/Tabs/SettingsTab.swift
git commit -m "feat(app): surface Cloud fallback row on ineligible devices"
```

---

### Task 21: Update UnsupportedDeviceView for new reasons

**Files:**
- Modify: `TalkNative/UnsupportedDeviceView.swift`

- [ ] **Step 1: Rewrite with new branches and a navigation primary button**

Replace the file contents with:

```swift
import SwiftUI
import UIKit
import EnhancerCore

struct UnsupportedDeviceView: View {
    let reason: LanguageModelAvailability.Reason

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: icon).font(.system(size: 56)).foregroundStyle(.secondary)
                Text(title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
                primaryAction
            }
            .padding(32)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch reason {
        case .apiKeyMissing:
            NavigationLink("Set up cloud fallback") { CloudFallbackSettingsView() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("cloud.setup.cta")
        case .appleIntelligenceNotEnabled:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url).buttonStyle(.borderedProminent)
            }
        case .networkUnavailable:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: url).buttonStyle(.bordered)
            }
        default:
            EmptyView()
        }
    }

    private var icon: String {
        switch reason {
        case .deviceNotEligible: return "exclamationmark.iphone"
        case .appleIntelligenceNotEnabled: return "gearshape"
        case .modelNotReady: return "icloud.and.arrow.down"
        case .apiKeyMissing: return "key"
        case .networkUnavailable: return "wifi.slash"
        case .other: return "exclamationmark.circle"
        }
    }

    private var title: String {
        switch reason {
        case .deviceNotEligible: return "This device doesn't support Apple Intelligence"
        case .appleIntelligenceNotEnabled: return "Apple Intelligence is off"
        case .modelNotReady: return "Apple Intelligence is downloading"
        case .apiKeyMissing: return "Set up cloud fallback"
        case .networkUnavailable: return "No network connection"
        case .other: return "Couldn't start TalkNative"
        }
    }

    private var message: String {
        switch reason {
        case .deviceNotEligible:
            return "TalkNative can still run on this device via cloud fallback. Set up an Anthropic API key to continue."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings → Apple Intelligence & Siri."
        case .modelNotReady:
            return "The model is still downloading. Come back in a few minutes."
        case .apiKeyMissing:
            return "This device doesn't support Apple Intelligence. You can still use TalkNative by connecting an Anthropic API key."
        case .networkUnavailable:
            return "Cloud fallback needs a network connection. Reconnect and try again."
        case .other(let s):
            return s
        }
    }
}
```

**Design note:** Previously, `.deviceNotEligible` was the terminal state shown to iPhone 13 Pro users. After this change, that case should no longer be reached on ineligible devices (ProviderSelector returns a cloud provider with `.apiKeyMissing` instead). The `.deviceNotEligible` branch remains as a fallback with copy that guides the user to set up cloud fallback, in case the provider chain short-circuits before cloud resolution.

- [ ] **Step 2: Build**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 3: Commit**

```bash
git add TalkNative/UnsupportedDeviceView.swift
git commit -m "feat(app): add cloud-tier branches to UnsupportedDeviceView"
```

---

## Phase 6 — Entitlements, URL scheme, project.yml

### Task 22: Add keychain-access-group entitlements

**Files:**
- Modify: `TalkNative/TalkNative.entitlements`
- Modify: `EnhanceExtension/EnhanceExtension.entitlements`

- [ ] **Step 1: Update TalkNative entitlements**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.axveer.talknative</string>
    </array>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)group.com.axveer.talknative</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Update EnhanceExtension entitlements (identical additions)**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.axveer.talknative</string>
    </array>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)group.com.axveer.talknative</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds. (Code signing disabled in CI; real devices need provisioning with matching capability.)

- [ ] **Step 4: Commit**

```bash
git add TalkNative/TalkNative.entitlements EnhanceExtension/EnhanceExtension.entitlements
git commit -m "build: add shared keychain-access-group to host + extension"
```

---

### Task 23: Register URL scheme for host-app deep link

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: Add CFBundleURLTypes under TalkNative target's Info.plist**

Modify `project.yml` — extend the `TalkNative.info.properties` block (currently just `UILaunchScreen` and `UISupportedInterfaceOrientations`):

```yaml
    info:
      path: TalkNative/Info.plist
      properties:
        UILaunchScreen: {}
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        CFBundleURLTypes:
          - CFBundleURLName: com.axveer.talknative.settings
            CFBundleURLSchemes:
              - com.axveer.talknative
```

- [ ] **Step 2: Regenerate**

Run:
```bash
xcodegen generate
```

Expected: project regenerates. Verify the generated `TalkNative/Info.plist` now includes the scheme.

- [ ] **Step 3: Commit**

```bash
git add project.yml TalkNative.xcodeproj TalkNative/Info.plist
git commit -m "build: register com.axveer.talknative URL scheme"
```

---

## Phase 7 — Extension wiring

### Task 24: Extension reads shared CredentialStore + routes new reasons

**Files:**
- Modify: `EnhanceExtension/ExtensionHostView.swift`

- [ ] **Step 1: Rewrite ExtensionServices to go through a selector**

Replace the `ExtensionServices` struct and its `make()` with:

```swift
@MainActor
struct ExtensionServices {
    let presets: PresetStore
    let history: HistoryStore
    let enhancer: Enhancer
    let provider: any LanguageModelProvider

    static func make() async -> ExtensionServices {
        let appGroupID = "group.com.axveer.talknative"
        let defaults = UserDefaults(suiteName: appGroupID) ?? .standard
        let presets = PresetStore(defaults: defaults)
        presets.seedIfNeeded()

        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        let container =
            (try? HistorySchema.makeContainer(appGroupURL: containerURL))
            ?? (try! HistorySchema.makeContainer(appGroupURL: nil))
        let history = HistoryStore(container: container)

        let credentials = CredentialStore(
            service: "com.axveer.talknative.cloud",
            accessGroup: "$(AppIdentifierPrefix)group.com.axveer.talknative"
        )
        let provider = await ExtensionProviderSelector.resolve(credentials: credentials, defaults: defaults)

        return ExtensionServices(
            presets: presets,
            history: history,
            enhancer: Enhancer(provider: provider),
            provider: provider
        )
    }
}
```

Add an extension-scoped selector at the bottom of the file:

```swift
private enum ExtensionProviderSelector {
    static func resolve(credentials: CredentialStore, defaults: UserDefaults) async -> any LanguageModelProvider {
        let foundation = FoundationModelsProvider()
        switch foundation.availability {
        case .available:
            return foundation
        case .unavailable(.deviceNotEligible):
            let key = (try? await credentials.load()) ?? nil
            let optIn = defaults.bool(forKey: "cloud.optInAccepted")
            let availability: LanguageModelAvailability =
                (key != nil && !(key!.isEmpty) && optIn) ? .available : .unavailable(.apiKeyMissing)
            let transport = AnthropicTransport(apiKey: key ?? "")
            return CloudLanguageModelProvider(
                transport: transport,
                model: "claude-haiku-4-5-20251001",
                availability: availability
            )
        case .unavailable:
            return foundation
        }
    }
}
```

Add `import CredentialStore` at the top.

- [ ] **Step 2: Update `begin()` to handle new reasons and open host app**

In `ExtensionHostView`, replace the `begin()` async function and the top of `body` so the `.unavailable` case routes based on reason:

```swift
@State private var services: ExtensionServices? = nil
// ...

var body: some View {
    Group {
        if let services {
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
                availabilityContent(for: services.provider.availability)
                    .task { await begin(services: services) }
            }
        } else {
            ProgressView().task {
                services = await ExtensionServices.make()
            }
        }
    }
}

@ViewBuilder
private func availabilityContent(for availability: LanguageModelAvailability) -> some View {
    switch availability {
    case .available:
        ProgressView()
    case .unavailable(.apiKeyMissing):
        VStack(spacing: 16) {
            Image(systemName: "key").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("Set up cloud fallback").font(.headline)
            Text("Open TalkNative to configure your Anthropic API key.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Open TalkNative") {
                if let url = URL(string: "com.axveer.talknative://settings/cloud") {
                    extensionContext?.open(url, completionHandler: nil)
                }
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    case .unavailable(.networkUnavailable):
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No network connection").font(.headline)
            Text("Cloud fallback needs a network connection.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Dismiss") { onDismiss() }.buttonStyle(.bordered)
        }
        .padding(24)
    case .unavailable:
        Color.clear.task { onDismiss() }
    }
}

private func begin(services: ExtensionServices) async {
    switch services.provider.availability {
    case .available:
        let vm = EnhancementViewModel(enhancer: services.enhancer)
        viewModel = vm
        await vm.start(inputText: initialText, activePresets: services.presets.activePresets)
    case .unavailable:
        // UI already reflects reason via availabilityContent(for:); do not
        // dismiss automatically — let the user tap a button.
        break
    }
}

@Environment(\.openURL) private var openURL
// (remove — use extensionContext?.open instead)
```

**Important:** the extension context is accessible as `extensionContext` on `UIViewController` but NOT directly in SwiftUI. Instead, use the existing `NSExtensionContext` wiring provided by the `ShareViewController` (which hosts this view). The pattern: add a `var onOpenHostApp: (URL) -> Void` closure to `ExtensionHostView`, pass it from the `ShareViewController`.

Refined closure wiring: add to `ExtensionHostView` properties:

```swift
let onOpenHostApp: ((URL) -> Void)?
```

In `ShareViewController` (find the existing file under `EnhanceExtension/`), pass it in:

```swift
let hostView = ExtensionHostView(
    initialText: extracted,
    mode: .share,
    onCopyAndDismiss: { [weak self] text in /* existing */ },
    onUseAndReturn: { [weak self] text in /* existing */ },
    onDismiss: { [weak self] in /* existing */ },
    onOpenHostApp: { [weak self] url in
        self?.extensionContext?.open(url, completionHandler: nil)
        self?.extensionContext?.completeRequest(returningItems: nil)
    }
)
```

In the settings button above, call `onOpenHostApp?(url)` instead of `extensionContext?.open(...)`.

*(If `ShareViewController.swift` doesn't exist yet in the expected path, find it first with `Glob` pattern `EnhanceExtension/**.swift` before editing.)*

- [ ] **Step 3: Build extension target**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add EnhanceExtension
git commit -m "feat(extension): route new availability reasons; open host app via URL scheme"
```

---

## Phase 8 — UI tests

### Task 25: LaunchArguments flags for UI tests

**Files:**
- Modify: `TalkNative/LaunchArguments.swift`

- [ ] **Step 1: Add two new flags**

Replace contents:

```swift
import Foundation

enum LaunchArguments {
    static let useStubEnhancerFlag = "-useStubEnhancer"
    static let useStubCloudFlag = "-useStubCloud"
    static let forceAvailabilityEnvKey = "TALKNATIVE_FORCE_AVAILABILITY"
    static let prefillInputEnvKey = "TALKNATIVE_PREFILL_INPUT"

    static var useStubEnhancer: Bool {
        CommandLine.arguments.contains(useStubEnhancerFlag)
    }

    static var useStubCloud: Bool {
        CommandLine.arguments.contains(useStubCloudFlag)
    }

    /// One of: "deviceNotEligible", "apiKeyMissing", "networkUnavailable",
    /// "available" (default), or nil to use the real availability.
    static var forcedAvailability: String? {
        ProcessInfo.processInfo.environment[forceAvailabilityEnvKey]
    }

    static var prefilledInput: String? {
        ProcessInfo.processInfo.environment[prefillInputEnvKey]
    }
}
```

- [ ] **Step 2: Honor the flags in AppServices.makeStubbed**

Modify the stubbed path in `AppServices.swift`. Find the `makeStubbed()` extension method and update it:

```swift
extension AppServices {
    static func makeStubbed() -> AppServices {
        let defaults = UserDefaults(suiteName: "ui-test.\(UUID().uuidString)")!
        let presetStore = PresetStore(defaults: defaults)
        presetStore.seedIfNeeded()
        let container = (try? HistorySchema.makeContainer(appGroupURL: nil))!
        let historyStore = HistoryStore(container: container)

        let availability: LanguageModelAvailability = {
            switch LaunchArguments.forcedAvailability {
            case "deviceNotEligible": return .unavailable(.deviceNotEligible)
            case "apiKeyMissing":     return .unavailable(.apiKeyMissing)
            case "networkUnavailable": return .unavailable(.networkUnavailable)
            default: return .available
            }
        }()

        let provider: any LanguageModelProvider
        if LaunchArguments.useStubCloud {
            // A stub-backed "cloud provider": behaves like cloud for identity
            // checks (`is CloudLanguageModelProvider`) while staying hermetic.
            provider = StubLanguageModelProvider(
                availability: availability,
                scriptedChunks: ["Hi ", "there"]
            )
        } else {
            provider = StubLanguageModelProvider(
                availability: availability,
                scriptedChunks: ["Hi ", "there"]
            )
        }

        let enhancer = Enhancer(provider: provider)
        let credentials = CredentialStore(
            service: "ui-test.\(UUID().uuidString)",
            accessGroup: nil
        )
        return AppServices(
            presetStore: presetStore,
            historyStore: historyStore,
            enhancer: enhancer,
            provider: provider,
            credentials: credentials
        )
    }
}
```

*(We keep `useStubCloud` as a separate flag for future use — e.g., if we later want a CloudLanguageModelProvider wired to a FakeTransport in UI tests. For v1 it's a marker; the provider type is the same.)*

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add TalkNative/LaunchArguments.swift TalkNative/AppServices.swift
git commit -m "test(app): add UI-test launch flags for cloud + forced availability"
```

---

### Task 26: UnsupportedDeviceCloudCTAUITests

**Files:**
- Create: `TalkNativeUITests/UnsupportedDeviceCloudCTAUITests.swift`

- [ ] **Step 1: Write the UI test**

```swift
import XCTest

final class UnsupportedDeviceCloudCTAUITests: XCTestCase {

    private func launch(forceAvailability reason: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer"]
        app.launchEnvironment = ["TALKNATIVE_FORCE_AVAILABILITY": reason]
        app.launch()
        return app
    }

    func testApiKeyMissingShowsSetupCTA() {
        let app = launch(forceAvailability: "apiKeyMissing")
        XCTAssertTrue(app.staticTexts["Set up cloud fallback"].waitForExistence(timeout: 5))
        let cta = app.buttons["cloud.setup.cta"]
        XCTAssertTrue(cta.exists)
    }

    func testCTANavigatesToCloudFallbackSettings() {
        let app = launch(forceAvailability: "apiKeyMissing")
        let cta = app.buttons["cloud.setup.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5))
        cta.tap()

        XCTAssertTrue(app.navigationBars["Cloud fallback"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.secureTextFields["cloud.key.field"].exists)
    }

    func testNetworkUnavailableShowsNetworkCopy() {
        let app = launch(forceAvailability: "networkUnavailable")
        XCTAssertTrue(app.staticTexts["No network connection"].waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 2: Run it**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeUITests/UnsupportedDeviceCloudCTAUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add TalkNativeUITests/UnsupportedDeviceCloudCTAUITests.swift
git commit -m "test(ui): add UnsupportedDeviceCloudCTAUITests"
```

---

### Task 27: CloudFallbackSettingsUITests

**Files:**
- Create: `TalkNativeUITests/CloudFallbackSettingsUITests.swift`

- [ ] **Step 1: Write the UI test**

```swift
import XCTest

final class CloudFallbackSettingsUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer"]
        app.launchEnvironment = ["TALKNATIVE_FORCE_AVAILABILITY": "apiKeyMissing"]
        app.launch()
        return app
    }

    private func openSettings(_ app: XCUIApplication) {
        let cta = app.buttons["cloud.setup.cta"]
        XCTAssertTrue(cta.waitForExistence(timeout: 5))
        cta.tap()
        XCTAssertTrue(app.navigationBars["Cloud fallback"].waitForExistence(timeout: 3))
    }

    func testPasteAndSaveMasksKey() {
        let app = launch()
        openSettings(app)

        let field = app.secureTextFields["cloud.key.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("sk-ant-ABCD1234")

        app.buttons["cloud.save"].tap()

        // After save, the pending field is cleared and the preview shows last 4.
        XCTAssertTrue(app.staticTexts["…1234"].waitForExistence(timeout: 3))
    }

    func testOptInToggleEnables() {
        let app = launch()
        openSettings(app)

        let toggle = app.switches["cloud.optIn"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        if toggle.value as? String == "0" { toggle.tap() }
        XCTAssertEqual(toggle.value as? String, "1")
    }

    func testInvalidPrefixShowsWarning() {
        let app = launch()
        openSettings(app)

        let field = app.secureTextFields["cloud.key.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("wrong-prefix")

        XCTAssertTrue(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] %@", "Doesn't look like an Anthropic key"
        )).firstMatch.waitForExistence(timeout: 3))
    }

    func testClearReturnsToEmptyState() {
        let app = launch()
        openSettings(app)

        let field = app.secureTextFields["cloud.key.field"]
        field.tap()
        field.typeText("sk-ant-9999")
        app.buttons["cloud.save"].tap()
        XCTAssertTrue(app.staticTexts["…9999"].waitForExistence(timeout: 3))

        app.buttons["cloud.clear"].tap()
        XCTAssertTrue(app.staticTexts["No key"].waitForExistence(timeout: 3))
    }
}
```

- [ ] **Step 2: Run it**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeUITests/CloudFallbackSettingsUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS. Keychain in the simulator works without codesigning.

- [ ] **Step 3: Commit**

```bash
git add TalkNativeUITests/CloudFallbackSettingsUITests.swift
git commit -m "test(ui): add CloudFallbackSettingsUITests"
```

---

### Task 28: Extend AppFlowTests with a cloud flow

**Files:**
- Modify: `TalkNativeTests/AppFlowTests.swift`

- [ ] **Step 1: Add a cloud-branch test**

Append inside the `@Suite` struct:

```swift
@Test func cloudProviderBranchProducesThreeVariantsEndToEnd() async throws {
    // Simulates an ineligible device that has set up cloud fallback: the
    // Enhancer consumes a CloudLanguageModelProvider wired to a scripted
    // StreamingChatTransport.
    struct ScriptedTransport: StreamingChatTransport {
        func streamText(system: String, user: String, model: String) -> AsyncThrowingStream<StreamEvent, Error> {
            AsyncThrowingStream { continuation in
                continuation.yield(.delta("Cloud "))
                continuation.yield(.delta("says hi"))
                continuation.yield(.done)
                continuation.finish()
            }
        }
    }
    let provider = CloudLanguageModelProvider(
        transport: ScriptedTransport(),
        model: "claude-haiku-4-5-20251001",
        availability: .available
    )
    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let presets = PresetStore(defaults: defaults)
    presets.seedIfNeeded()
    let container = try HistorySchema.makeContainer(appGroupURL: nil)
    let history = HistoryStore(container: container)
    let enhancer = Enhancer(provider: provider)
    let credentials = CredentialStore(service: "t.\(UUID())", accessGroup: nil)
    let services = AppServices(
        presetStore: presets,
        historyStore: history,
        enhancer: enhancer,
        provider: provider,
        credentials: credentials
    )
    let vm = EnhancementViewModel(enhancer: enhancer)

    await vm.start(inputText: "hey", activePresets: services.presetStore.activePresets)
    await vm.waitForCompletion()

    #expect(vm.variantStates.count == 3)
    #expect(vm.variantStates.allSatisfy { $0.phase == .completed })
    #expect(vm.variantStates.allSatisfy { $0.text == "Cloud says hi" })
}
```

Add `import CredentialStore` at the top of the file if not present.

- [ ] **Step 2: Run the suite**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeTests/AppFlowTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: all tests PASS, including the new one.

- [ ] **Step 3: Commit**

```bash
git add TalkNativeTests/AppFlowTests.swift
git commit -m "test(app): extend AppFlowTests with cloud-provider end-to-end flow"
```

---

## Phase 9 — Smoke test + CI

### Task 29: Add CloudProviderSmokeTests

**Files:**
- Create: `DeviceSmokeTests/CloudProviderSmokeTests.swift`

- [ ] **Step 1: Create the smoke suite**

```swift
import Testing
import Foundation
import EnhancerCore

@Suite("Cloud provider smoke — runs when ANTHROPIC_API_KEY_SMOKE is set")
struct CloudProviderSmokeTests {

    private static var apiKey: String? {
        ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY_SMOKE"]
    }

    private static func hasKey() -> Bool {
        guard let k = apiKey, !k.isEmpty else { return false }
        return true
    }

    private let inputs = [
        "hey can u send me the docs asap thx",
        "I would like to kindly request your attendance to the upcoming meeting",
        "it a funny situation but i dont know what to do with",
        "hit the nail on the head i think",
        "ok",
    ]

    @Test(.enabled(if: CloudProviderSmokeTests.hasKey()))
    func eachInputProducesNonEmptyDifferentOutputPerBuiltInPreset() async throws {
        let key = try #require(Self.apiKey)
        let transport = AnthropicTransport(apiKey: key)
        let provider = CloudLanguageModelProvider(
            transport: transport,
            model: "claude-haiku-4-5-20251001",
            availability: .available
        )
        let enhancer = Enhancer(provider: provider)

        for text in inputs {
            let variants = [
                VariantRequest(presetID: UUID(), presetLabel: "Casual",
                               presetInstructions: "Everyday conversational language."),
                VariantRequest(presetID: UUID(), presetLabel: "Professional",
                               presetInstructions: "Business-appropriate, courteous."),
                VariantRequest(presetID: UUID(), presetLabel: "Warm",
                               presetInstructions: "Kind, considerate phrasing."),
            ]
            let request = EnhancementRequest(inputText: text, variants: variants)

            var outputs: [UUID: String] = [:]
            for await event in enhancer.enhance(request) {
                if case let .completed(pid, full) = event { outputs[pid] = full }
            }
            for v in variants {
                let produced = outputs[v.presetID] ?? ""
                #expect(!produced.isEmpty, "empty output for \(v.presetLabel) on \(text)")
                #expect(produced != text, "unchanged output for \(v.presetLabel)")
            }
        }
    }
}
```

- [ ] **Step 2: Run locally — confirm it skips without the env var**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme DeviceSmokeTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: the existing Foundation Models smoke runs as usual; the new cloud smoke is skipped when the env var is absent.

- [ ] **Step 3: Commit**

```bash
git add DeviceSmokeTests/CloudProviderSmokeTests.swift
git commit -m "test(smoke): add CloudProviderSmokeTests (opt-in via env var)"
```

---

### Task 30: CI — add CredentialStore package job and cloud-smoke workflow

**Files:**
- Modify: `.github/workflows/ci.yml`
- Create: `.github/workflows/cloud-smoke.yml`

- [ ] **Step 1: Add the CredentialStore SPM test to CI**

Modify `.github/workflows/ci.yml` — append one step inside the `packages` job:

```yaml
      - name: Test CredentialStore
        run: swift test --package-path Packages/CredentialStore
```

*(If Keychain isn't reachable from the CLI, the suite skips via `isKeychainAvailable`. That's by design.)*

- [ ] **Step 2: Create the cloud-smoke workflow**

Create `.github/workflows/cloud-smoke.yml`:

```yaml
name: Cloud Smoke

on:
  workflow_dispatch:

env:
  XCODE_APP: /Applications/Xcode_26.4.app
  IOS_DESTINATION: platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4

jobs:
  cloud-smoke:
    runs-on: macos-26
    # Do not run on forks — secrets are not forwarded there anyway, but
    # this makes the intent explicit.
    if: github.event.repository.fork == false
    steps:
      - uses: actions/checkout@v4
      - name: Select Xcode
        run: sudo xcode-select -s "$XCODE_APP"
      - name: Install xcodegen
        run: brew install xcodegen
      - name: Generate project
        run: xcodegen generate
      - name: Run DeviceSmokeTests (with cloud key)
        env:
          ANTHROPIC_API_KEY_SMOKE: ${{ secrets.ANTHROPIC_API_KEY_SMOKE }}
        run: |
          if [ -z "$ANTHROPIC_API_KEY_SMOKE" ]; then
            echo "No ANTHROPIC_API_KEY_SMOKE secret set; nothing to run."
            exit 0
          fi
          xcodebuild test \
            -project TalkNative.xcodeproj \
            -scheme DeviceSmokeTests \
            -destination "$IOS_DESTINATION" \
            CODE_SIGNING_ALLOWED=NO
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml .github/workflows/cloud-smoke.yml
git commit -m "ci: test CredentialStore + add opt-in cloud-smoke workflow"
```

---

## Phase 10 — Copy, docs, no-network guard

### Task 31: Narrow no-network-check.sh

**Files:**
- Modify: `scripts/no-network-check.sh`

- [ ] **Step 1: Rewrite the script to scope the check**

Replace contents:

```bash
#!/usr/bin/env bash
set -euo pipefail

# After the v1.1 cloud-fallback-tier amendment, networking is allowed in the
# cloud provider source files. Two surfaces must remain strictly on-device:
#   1. FoundationModelsProvider.swift
#   2. Everything in EnhancerUI
FORBIDDEN='URLSession|\bNetwork\b|NWConnection|URLRequest|URLProtocol'

FILES=(
  "Packages/EnhancerCore/Sources/EnhancerCore/FoundationModelsProvider.swift"
)
DIRS=(
  "Packages/EnhancerUI/Sources"
)

hits=""
for f in "${FILES[@]}"; do
  if [[ -f "$f" ]]; then
    match=$(grep -nE "$FORBIDDEN" "$f" || true)
    if [[ -n "$match" ]]; then hits+="$f:\n$match\n"; fi
  fi
done
for d in "${DIRS[@]}"; do
  if [[ -d "$d" ]]; then
    match=$(grep -rnE "$FORBIDDEN" "$d" --include='*.swift' || true)
    if [[ -n "$match" ]]; then hits+="$match\n"; fi
  fi
done

if [[ -n "$hits" ]]; then
  echo "ERROR: network API usage detected in on-device-only surfaces:"
  printf "%b" "$hits"
  exit 1
fi
echo "OK: on-device-only surfaces are free of network APIs"
```

- [ ] **Step 2: Run it locally**

Run:
```bash
./scripts/no-network-check.sh
```

Expected: "OK: on-device-only surfaces are free of network APIs". If it flags anything, fix or justify.

- [ ] **Step 3: Commit**

```bash
git add scripts/no-network-check.sh
git commit -m "ci: narrow no-network guard to FoundationModelsProvider + EnhancerUI"
```

---

### Task 32: Update AboutView and PrivacyView copy

**Files:**
- Modify: `TalkNative/Settings/AboutView.swift`
- Modify: `TalkNative/Settings/PrivacyView.swift`

- [ ] **Step 1: Update AboutView**

Replace the two existing `Text(...)` blocks (lines 8–13) with the tier-aware copy:

```swift
Text(
    "An on-device text enhancer that helps non-native English speakers write messages that sound native — across casual and professional registers."
)
Text(
    "On iPhone 15 Pro, iPhone 16 and newer, and iPads with M1 or newer, all processing runs on your device using Apple Intelligence. No accounts, no network, no tracking."
)
Text(
    "On earlier devices, TalkNative can optionally use Anthropic's Claude API with an API key you provide. In that mode, text you enhance is sent to Anthropic's servers. You can add or remove the key in Settings at any time."
)
```

- [ ] **Step 2: Update PrivacyView**

Replace contents:

```swift
import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy").font(.title2.bold())

                Group {
                    Text("On-device tier")
                        .font(.headline)
                    Text("On Apple-Intelligence-capable devices, all text you enhance is processed on your device. TalkNative has no network layer for this tier.")
                    Text("Recent items and presets are stored on your device only, never synced, never uploaded.")
                    Text("You can clear history at any time from Settings → History.")
                }

                Divider()

                Group {
                    Text("Cloud fallback")
                        .font(.headline)
                    Text("On devices Apple excludes from Apple Intelligence, TalkNative can use Anthropic's Claude API with an API key you provide. When enabled:")
                    Text("• Your API key is stored in the iOS Keychain on this device only.")
                    Text("• The key is never synced to iCloud, backed up, or transmitted anywhere except as an authentication header to api.anthropic.com.")
                    Text("• Only the text you enhance is sent to Anthropic's servers over HTTPS. No telemetry, no history, no personal identifiers.")
                    Text("• You can clear the key at any time from Settings → Cloud fallback.")
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("Privacy")
    }
}
```

- [ ] **Step 3: Build**

Run:
```bash
xcodebuild build -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  CODE_SIGNING_ALLOWED=NO
```

Expected: succeeds.

- [ ] **Step 4: Commit**

```bash
git add TalkNative/Settings/AboutView.swift TalkNative/Settings/PrivacyView.swift
git commit -m "docs(app): two-tier privacy + About copy for cloud fallback"
```

---

### Task 33: Update README

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append tier + BYOK sections**

Replace the contents with:

```markdown
# TalkNative

An iOS text enhancer for non-native English speakers.

TalkNative ships two enhancement tiers:

- **On-device (default where supported).** On iPhone 15 Pro / Pro Max, all iPhone 16+, and iPads with M1 or newer, all processing happens on-device using Apple Foundation Models. No accounts, no network, no tracking.
- **BYOK cloud fallback.** On devices Apple excludes from Apple Intelligence (A15/A16 iPhones, non-Pro iPhone 15, older iPads), TalkNative can optionally use Anthropic's Claude API with an API key you provide. The key is stored in the device Keychain and never transmitted anywhere except as an authentication header to Anthropic.

## Requirements
- macOS with Xcode 16+ (project currently pinned to Xcode 26.4)
- iOS 26 simulator or device (Apple Intelligence device for the on-device tier)
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
swift test --package-path Packages/CredentialStore
```

Xcode-hosted tests (app and UI):
```
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4'
```

## Setting up cloud fallback

On an ineligible device:
1. Open TalkNative. The unsupported-device screen offers **Set up cloud fallback**.
2. Paste your Anthropic API key (starts with `sk-ant-`).
3. Accept the disclosure toggle.
4. Enhancement is now available; the key lives in the Keychain and is shared with the Share extension.

### Known v1 limitation

The Action extension (in-place text replacement) is deferred to v1.1. The Share extension covers the primary invocation flow. See the v1 spec section "Invocation surfaces" for intent.

## Design specs

- `docs/superpowers/specs/2026-04-18-talknative-design.md` — v1 on-device design.
- `docs/superpowers/specs/2026-04-18-cloud-fallback-tier-design.md` — v1.1 cloud fallback amendment.

## Implementation plans

- `docs/superpowers/plans/2026-04-18-talknative-implementation.md` — v1.
- `docs/superpowers/plans/2026-04-18-cloud-fallback-tier-implementation.md` — v1.1 (this plan).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: describe both tiers and BYOK setup in README"
```

---

## Phase 11 — Final verification and manual acceptance

### Task 34: Run swift-format lint

**Files:** none (lint only)

- [ ] **Step 1: Run the linter**

Run:
```bash
./scripts/lint.sh
```

Expected: no lint errors. If any, fix them inline and re-run. Keep the fix as a single follow-up commit if meaningful.

---

### Task 35: Run the full test matrix

- [ ] **Step 1: SPM package tests**

Run in parallel (separate shells OK):
```bash
swift test --package-path Packages/EnhancerCore
swift test --package-path Packages/PresetKit
swift test --package-path Packages/HistoryKit
swift test --package-path Packages/EnhancerUI
swift test --package-path Packages/CredentialStore
```

Expected: all PASS.

- [ ] **Step 2: TalkNativeTests**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeTests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 3: TalkNativeUITests**

Run:
```bash
xcodebuild test -project TalkNative.xcodeproj -scheme TalkNative \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -only-testing:TalkNativeUITests \
  CODE_SIGNING_ALLOWED=NO
```

Expected: PASS.

- [ ] **Step 4: no-network-check**

Run:
```bash
./scripts/no-network-check.sh
```

Expected: "OK: on-device-only surfaces are free of network APIs".

---

### Task 36: Manual acceptance on real hardware

*(No automated steps — real-device verification. Check each item once the build is on-device.)*

- [ ] Install on iPhone 13 Pro (A15). The splash shows briefly, then `UnsupportedDeviceView` appears with the **Set up cloud fallback** CTA.
- [ ] Tap CTA. `CloudFallbackSettingsView` appears.
- [ ] Paste a valid Anthropic key. Save. The masked preview `…xxxx` appears.
- [ ] Toggle the opt-in disclosure **on**. Navigate back; the main app UI becomes available.
- [ ] Type a short message and tap **Enhance**. Three streamed variants appear, one per active preset.
- [ ] Cancel mid-enhancement. UI shows **"Cancelled."**, not **"Something went wrong."**
- [ ] Turn Airplane Mode on. Attempt to enhance. `UnsupportedDeviceView` shows the `.networkUnavailable` copy.
- [ ] In Safari, select text and invoke the Share extension → TalkNative. Without opt-in, the extension shows **Open TalkNative**; tapping it opens the host app at the Cloud fallback settings screen via the `com.axveer.talknative://settings/cloud` scheme. With opt-in, enhancement runs directly in the Share sheet.
- [ ] In Settings → Cloud fallback, tap **Clear key**. The main tab flips back to the CTA state immediately (scene-phase rebootstrap).
- [ ] Install on iPhone 16 (A18). The Cloud fallback settings section is absent; behavior is identical to today's v1.

---

## Self-review

**Spec coverage check (items from the spec):**

- `CloudLanguageModelProvider` — Task 10.
- `StreamingChatTransport` + `AnthropicTransport` — Tasks 5, 8, 9.
- `SSEStream` — Task 6.
- `CredentialStore` package — Tasks 1, 2.
- `ProviderSelector` — Task 14.
- `CloudFallbackSettingsView` — Tasks 18, 19.
- `UnsupportedDeviceView` updates — Task 21.
- URL scheme — Task 23.
- Entitlements — Task 22.
- `project.yml` updates — Tasks 12, 23.
- `LanguageModelAvailability.Reason` additions — Task 3.
- `EnhancerError` message updates — Task 4.
- Privacy/About copy — Task 32.
- `no-network-check.sh` narrowing — Task 31.
- New SPM CI job — Task 30.
- Cloud smoke workflow — Task 30.
- `DeviceSmokeTests` additions — Task 29.
- `TalkNativeUITests` additions — Tasks 26, 27.
- `TalkNativeTests` additions — Tasks 14 (selector), 28 (cloud flow).
- Extension wiring — Task 24.
- Scene-phase re-resolution — Task 17.
- Async `AppServices` bootstrap — Tasks 15, 16.
- Keychain locked edge case — covered by `CredentialStore.load()` returning nil on `errSecInteractionNotAllowed` (Task 1).
- Soft invalid-prefix warning — covered in `CloudFallbackViewModel.pendingKeyChanged` (Task 18) and surfaced in view (Task 19) and UI test (Task 27).
- 60s timeout for cloud — covered in `AnthropicTransport.buildRequest` (Task 8: `timeoutInterval: 60`).
- Cancellation correctness — covered in `AnthropicTransport.streamText` (Task 8: `onTermination`) and dedicated test in Task 9.
- Telemetry policy — nothing to implement; the plan ships no code that emits telemetry.
- README update — Task 33.
- Manual acceptance — Task 36.

All spec items mapped to at least one task.

**Placeholder scan:** no `TBD`, `TODO`, or "handle appropriately" phrasing. Every code step contains complete code.

**Type consistency:**
- `CloudLanguageModelProvider(transport:model:availability:)` — consistent across Tasks 10, 14, 24, 28, 29.
- `StreamingChatTransport.streamText(system:user:model:)` — consistent across Tasks 5, 8, 10, 28, 29.
- `CredentialStore(service:accessGroup:)` — consistent across Tasks 1, 14, 15, 24.
- `CredentialStore.save(_:)` / `load()` / `clear()` — consistent across all referring tasks.
- `ProviderSelector.resolve(availabilityProvider:credentials:defaults:)` — consistent in Tasks 14, 15.
- `SystemAvailabilityProvider` protocol — defined in Task 14, used by `FoundationModelsProvider` extension in the same task.
- `LanguageModelAvailability.Reason` cases `.apiKeyMissing`, `.networkUnavailable` — consistent across Tasks 3, 4, 14, 21, 24, 25, 26.
- `CloudDefaults.optInAcceptedKey` = `"cloud.optInAccepted"` — matches string literal in Task 24 (extension selector reads the same key).

All signatures and property names match across tasks.
