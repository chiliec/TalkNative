# TalkNative — Cloud Fallback Tier (Design Spec)

**Date:** 2026-04-18
**Status:** Approved for implementation planning
**Amends:** `2026-04-18-talknative-design.md`

## Summary

TalkNative's primary tier runs entirely on-device via Apple Foundation Models and remains unchanged. This spec adds a **second, opt-in cloud tier** for devices that Apple excludes from Apple Intelligence — specifically: iPhone 13 series, iPhone 14 series (including Pro/Pro Max), iPhone 15 and 15 Plus (non-Pro), and iPads that are neither M1+ nor A17 Pro. On those devices, a bring-your-own-key (BYOK) Anthropic Claude Haiku 4.5 client is selected instead of `FoundationModelsProvider` behind the existing `LanguageModelProvider` protocol. The `Enhancer` actor, UI, and extensions remain provider-agnostic.

## Motivation

1. **Users exist on ineligible hardware.** Pre-A17-Pro iPhones are still current devices; locking them out makes the app unusable for a significant share of its target audience.
2. **The protocol seam already exists.** `LanguageModelProvider` was designed as an abstraction boundary. Adding a second conformance is additive, not structural.
3. **BYOK keeps ownership and cost with the user.** No backend, no key-abuse surface, no running costs. Smallest engineering commitment that yields a shippable fallback.

## Scope and non-goals

### In scope

- A new `CloudLanguageModelProvider` conforming to `LanguageModelProvider`, fronted by an Anthropic Claude Haiku 4.5 client over streaming SSE.
- A new `CredentialStore` package using Keychain + App Group keychain-access-group for host/extension sharing.
- `ProviderSelector` helper that chooses between `FoundationModelsProvider` and `CloudLanguageModelProvider` at boot and on scene-phase change.
- `CloudFallbackSettingsView` — API key entry, opt-in disclosure, connection test.
- Updates to `UnsupportedDeviceView` with a CTA deep-linking to the new Settings section.
- A URL scheme `com.axveer.talknative://settings/cloud` used by the Share extension to nudge users into the host app's settings.
- Test coverage: pure unit tests for transport/provider/SSE; Keychain round-trip; provider selection; UI tests for settings flow and CTA; opt-in cloud smoke suite gated by env var.

### Out of scope

- OpenAI, Gemini, or any non-Anthropic provider for v1. Provider enum and Settings UI reserve space but ship with only Anthropic selectable.
- Developer-funded proxy, IAP-gated allowances, or any server-side component. These are the "proxy later" half of the chosen strategy and are explicitly deferred.
- Cloud option on Apple-Intelligence-capable devices. Capable hardware stays purely on-device; no toggle, no override.
- Automatic retry/backoff inside the provider. User-initiated retry via the existing UI affordance is the only retry.
- Per-preset cloud overrides, quality toggles, or any UI suggesting tier-mixing.

## Amendments to the original spec

The following clauses of `2026-04-18-talknative-design.md` are superseded by this spec:

1. **Constraint "On-device only. Zero network calls anywhere in the app."** — No longer universal. The constraint becomes:
   > On Apple-Intelligence-capable devices, enhancement is on-device only. On ineligible devices, enhancement runs via user-provided cloud credentials, with explicit one-time opt-in disclosure and Keychain-stored keys. Apple-Intelligence-capable devices have no cloud code path.
2. **CI grep test that fails on `URLSession`, `Network`, `NWConnection`.** Removed. Replaced by a narrower CI check: `FoundationModelsProvider.swift` and `EnhancerUI` must contain no networking imports. Networking is permitted only in the cloud provider source files.
3. **"Apple Intelligence required" row in Constraints.** Rewritten as: "Apple Intelligence required for the on-device tier. Ineligible devices may use the BYOK cloud tier."
4. **Privacy statement in Settings → Privacy.** Updated copy in `PrivacyView.swift` and `AboutView.swift` to reflect the two-tier model. Exact copy is specified in the Privacy and disclosure section below.
5. **Manual acceptance check "Install on iPhone 14 — unsupported-device view appears".** Rewritten as: "Install on an ineligible device — the unsupported-device view appears with a 'Set up cloud fallback' CTA; entering a valid API key and accepting the disclosure unlocks full app functionality."

All other clauses of the original spec remain in force.

## Architecture

### High-level shape

```
┌─────────────────────────────────────────────────────────────┐
│ TalkNative (app)            EnhanceExtension (share)        │
│   AppServices.bootstrap()     ExtensionHostView             │
│          │                          │                       │
│          └──────────┬───────────────┘                       │
│                     ▼                                       │
│            ProviderSelector                                 │
│   (reads Foundation Models availability + Keychain state)   │
│                     │                                       │
│      ┌──────────────┴──────────────┐                        │
│      ▼                             ▼                        │
│ FoundationModelsProvider   CloudLanguageModelProvider       │
│   (unchanged)               (new; Anthropic SSE)            │
└─────────────────────────────────────────────────────────────┘
           ▲                                    ▲
           │                                    │
     iOS SystemLanguageModel              CredentialStore
                                          (new; Keychain + App Group)
```

### Package layout

- **`Packages/EnhancerCore`** — add `CloudLanguageModelProvider.swift`, `SSEStream.swift`, `AnthropicTransport.swift`, `StreamingChatTransport.swift`. Extend `LanguageModelAvailability.Reason` with `.apiKeyMissing` and `.networkUnavailable`. `FoundationModelsProvider` is not modified.
- **`Packages/CredentialStore`** *(new leaf package)* — thin Keychain wrapper with `kSecAttrAccessGroup`. Consumed by `TalkNative`, `EnhanceExtension`, and test targets. Kept separate so `EnhancerCore` remains pure Foundation/model and all `Security.framework` usage lives in one place.
- **`TalkNative`** — adds `ProviderSelector.swift`, `Settings/CloudFallbackSettingsView.swift`, updates `UnsupportedDeviceView.swift`, extends `AppServices.swift` with async bootstrap and scene-phase re-resolution. Registers URL scheme in `Info.plist`.
- **`EnhanceExtension`** — entitlements updated for shared keychain-access-group and URL-handler fallback. No new files.

### Entitlement and project.yml changes

- Add `keychain-access-groups = [$(AppIdentifierPrefix)group.com.axveer.talknative]` to both `TalkNative.entitlements` and `EnhanceExtension.entitlements`.
- Add `CredentialStore` package entry to `project.yml` and wire it as a dependency of `TalkNative`, `EnhanceExtension`, `TalkNativeTests`, and `TalkNativeUITests`.
- Add `CFBundleURLTypes` entry in `TalkNative/Info.plist` registering the `com.axveer.talknative` scheme.

### What does NOT change

- `Enhancer` actor, streaming state machine, prompt assembly.
- `FoundationModelsProvider` — not a line.
- `StubLanguageModelProvider`, existing unit tests.
- Entire `PresetKit`, `HistoryKit`, `EnhancerUI` packages.
- Apple-Intelligence experience on capable hardware.

## Components

### `CloudLanguageModelProvider` *(EnhancerCore)*

```swift
public struct CloudLanguageModelProvider: LanguageModelProvider {
    public let availability: LanguageModelAvailability
    private let transport: any StreamingChatTransport
    private let model: String

    public init(transport: any StreamingChatTransport, model: String)
    public func stream(instructions: String, prompt: String)
        -> AsyncThrowingStream<String, Error>
}
```

Construction-time availability is decided from: Keychain key presence AND App Group defaults flag `cloud.optInAccepted`. Both must be true for `.available`; otherwise `.unavailable(.apiKeyMissing)`. Availability re-evaluates on scene-phase `.active`.

`stream(instructions:prompt:)` composes `system = instructions`, `user = prompt` and delegates to the transport.

### `StreamingChatTransport` + `AnthropicTransport` *(EnhancerCore)*

```swift
public protocol StreamingChatTransport: Sendable {
    func streamText(system: String, user: String, model: String)
        -> AsyncThrowingStream<StreamEvent, Error>
}

public enum StreamEvent: Sendable {
    case delta(String)
    case done
    case refusal(String)
}
```

`AnthropicTransport` targets `POST https://api.anthropic.com/v1/messages` with headers `anthropic-version: 2023-06-01`, `x-api-key: <key>`, body `{"model": model, "stream": true, "system": system, "messages": [{"role": "user", "content": user}], "max_tokens": 1024}`. Reads the response via `URLSession.bytes(for:)` into `SSEStream`.

Parsing map:
- SSE event `content_block_delta` with `delta.type == "text_delta"` → `.delta(delta.text)`.
- SSE event `message_stop` → `.done` (terminates the stream).
- SSE event `message_delta` with `delta.stop_reason == "refusal"` → `.refusal(...)`.

Transport is pure value type; takes a caller-injected `URLSession` (default `.shared`).

### `SSEStream` *(EnhancerCore, internal)*

Internal helper that consumes `URLSession.AsyncBytes` and yields `(event: String, data: String)` pairs per SSE frame. ~80 lines. Handles multi-line `data:` concatenation, empty-line frame terminators, and `event:` lines. No third-party deps.

### `CredentialStore` *(new leaf package)*

```swift
public struct CredentialStore: Sendable {
    public init(service: String, accessGroup: String)
    public func save(_ key: String) async throws
    public func load() async throws -> String?
    public func clear() async throws

    public enum Error: Swift.Error { case osError(OSStatus) }
}
```

- `service = "com.axveer.talknative.cloud"`, `accessGroup = "$(AppIdentifierPrefix)group.com.axveer.talknative"`.
- `kSecClassGenericPassword`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (prevents iCloud Keychain sync).
- `load()` on a locked device treats `errSecInteractionNotAllowed` as `nil` — same as "no key".
- Methods are `async` to keep Keychain I/O off the main actor at call sites.

### `ProviderSelector` *(TalkNative target)*

```swift
@MainActor
enum ProviderSelector {
    static func resolve(credentials: CredentialStore,
                        defaults: UserDefaults) async
        -> any LanguageModelProvider
}
```

Selection table:

| SystemLanguageModel availability | Key present | optIn | Returns |
|---|---|---|---|
| `.available` | — | — | `FoundationModelsProvider()` |
| `.unavailable(.deviceNotEligible)` | yes | yes | `CloudLanguageModelProvider(...)`, `.available` |
| `.unavailable(.deviceNotEligible)` | yes | no | `CloudLanguageModelProvider(...)`, `.unavailable(.apiKeyMissing)` |
| `.unavailable(.deviceNotEligible)` | no | — | `CloudLanguageModelProvider(...)`, `.unavailable(.apiKeyMissing)` |
| `.unavailable(.appleIntelligenceNotEnabled)` | — | — | `FoundationModelsProvider()` (unchanged) |
| `.unavailable(.modelNotReady)` | — | — | `FoundationModelsProvider()` (unchanged) |

`AppServices.makeProduction()` becomes `async` and awaits `ProviderSelector.resolve`. UI bootstrap in `TalkNativeApp.swift` is updated to run the async bootstrap before presenting `RootView`.

### `LanguageModelAvailability.Reason` — additions

```swift
public enum Reason: Sendable, Equatable {
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case apiKeyMissing           // NEW — covers missing key OR missing opt-in
    case networkUnavailable      // NEW — for mid-session drops at stream start
    case other(String)
}
```

`EnhancerError.modelUnavailable(.apiKeyMissing)` gets a new user-facing message ("Cloud API key isn't set up. Open Settings to add one."); `.networkUnavailable` gets "Cloud fallback needs a network connection."

### `CloudFallbackSettingsView` *(TalkNative/Settings)*

Visible only when `SystemLanguageModel.default.availability == .unavailable(.deviceNotEligible)`.

Sections:
1. **Status** — "Key saved" / "No key" indicator; one-tap "Test connection" that sends `max_tokens: 1` to the real endpoint and surfaces HTTP status.
2. **API key** — `SecureField` with paste affordance, save + clear buttons, masked display post-save (last 4 chars). Soft inline warning if the pasted string does not match `sk-ant-*` (user can save anyway).
3. **Provider** — `Picker` showing three options: `Anthropic Claude Haiku 4.5` (selectable), `OpenAI (coming soon)` (disabled), `Google Gemini (coming soon)` (disabled).
4. **Disclosure** — explanatory text plus a `Toggle` that must be on for the provider to report `.available`. Toggle state is stored in App Group defaults under key `cloud.optInAccepted`, so the Share extension reads the same flag.

Accessibility identifiers: `cloud.key.field`, `cloud.save`, `cloud.clear`, `cloud.test`, `cloud.optIn`, `cloud.provider`.

### `UnsupportedDeviceView` — updates

Adds two new branches:
- `.apiKeyMissing`: title "Set up cloud fallback", body "This device doesn't support Apple Intelligence. You can still use TalkNative by connecting an Anthropic API key.", primary button "Open Settings" → pushes `CloudFallbackSettingsView`.
- `.networkUnavailable`: title "No network connection", body "Cloud fallback needs a network connection. Reconnect and try again.", secondary link to iOS Settings.

## Data flow

### Cold boot on ineligible device

```
App launch
 └─ AppServices.makeProduction()  [async]
     └─ ProviderSelector.resolve(credentials:defaults:)
         ├─ SystemLanguageModel.default.availability → .unavailable(.deviceNotEligible)
         ├─ credentials.load()
         ├─ defaults.bool(forKey: "cloud.optInAccepted")
         └─ returns CloudLanguageModelProvider(...)
              availability =
                • .available              if key ∧ optIn
                • .unavailable(.apiKeyMissing)   otherwise
```

`RootView.swift:8` routes on `services.provider.availability` as it does today; `.apiKeyMissing` renders `UnsupportedDeviceView` with the cloud CTA.

### Enhancement happy path via cloud

```
User taps "Enhance"
 └─ Enhancer.run(request:)
     └─ for each active preset (sequential):
         └─ provider.stream(instructions:, prompt:)
             └─ CloudLanguageModelProvider
                 └─ AnthropicTransport.streamText(system:, user:, model:)
                     └─ URLSession.bytes(for: POST /v1/messages)
                         └─ SSEStream parses event/data pairs
                             └─ emits .delta(String) → provider yields String
                                 └─ Enhancer fills the preset card
                     └─ on message_stop → stream finishes normally
```

Cancellation chain: UI cancel → `Task.cancel()` → `AsyncThrowingStream` `onTermination` → `URLSessionDataTask.cancel()` → iterator throws `URLError.cancelled` → mapped to `EnhancerError.cancelled`. Cloud request timeout is 60s (vs. 30s default) to tolerate longer mid-stream stalls.

### Share extension invocation on ineligible device

Same `ProviderSelector.resolve()` runs in the extension process. Keychain access succeeds because the extension shares the keychain-access-group; App Group defaults read succeeds because the extension shares the group container. Existing switch in `ExtensionHostView.swift:43` routes:

- `.available` → `EnhancementSheet` (unchanged).
- `.apiKeyMissing` → "Open TalkNative to set up cloud fallback" copy with a button that opens `com.axveer.talknative://settings/cloud` via `extensionContext?.open(_:completionHandler:)`.
- `.networkUnavailable` → inline "No network" banner with retry.

### Scene-phase re-check

`RootView` listens to `@Environment(\.scenePhase)`. On transition to `.active`, re-runs `ProviderSelector.resolve()`. Catches: Apple Intelligence turned on since last launch; network returned; opt-in toggled in Settings while app was backgrounded. Cheap — one Keychain read + one availability probe, no network.

### Key rotation / clear

```
Settings → Cloud fallback → "Clear key"
 └─ CredentialStore.clear()
 └─ posts .cloudCredentialsChanged Notification on App Group
 └─ RootView re-runs ProviderSelector.resolve
 └─ availability → .apiKeyMissing
```

"Test connection" uses the same transport with a 1-token request. Save happens before test, so the user can recover from a typo without re-pasting.

## Error handling

### Error mapping table

| Origin | Signal | EnhancerError case | User message |
|---|---|---|---|
| DNS / offline | `URLError.notConnectedToInternet`, `.dataNotAllowed`, `.cannotFindHost` | `.modelUnavailable(.networkUnavailable)` | "Cloud fallback needs a network connection." |
| TLS / unreachable | `URLError.secureConnectionFailed`, `.cannotConnectToHost` | `.modelUnavailable(.networkUnavailable)` | same |
| Bad auth | HTTP 401/403 with `authentication_error` or `permission_error` | `.modelUnavailable(.apiKeyMissing)` | "Cloud API key isn't valid. Re-enter it in Settings." |
| Rate limited | HTTP 429 | `.rateLimited` | existing |
| Overloaded | HTTP 529 | `.rateLimited` | existing |
| Too big | HTTP 413, or 400 `invalid_request_error` re: tokens | `.exceededContextWindow` | existing |
| Content refusal | SSE `message_delta` with `stop_reason: "refusal"`, or 400 safety error | `.guardrailViolation` | existing |
| Mid-stream drop | stream ends before `message_stop`, `URLError.networkConnectionLost` | `.unknown("Connection interrupted")`, retryable | existing |
| User cancelled | `Task.checkCancellation()` | `.cancelled` | existing |
| Other 5xx | HTTP 500/502/503/504 | `.unknown("Server error \(code)")`, retryable | existing |
| Parse failure | decode error in SSE/transport | `.unknown("Parse error: \(desc)")` | existing |

### Retry policy

- **No automatic retry inside the provider.** All retries are user-initiated via the existing retry affordance in `EnhancementSheet`.
- `EnhancerError.isRetryable` (existing) already marks `.rateLimited` and `.unknown` as retryable — no change needed.

### Cancellation correctness

`AnthropicTransport.streamText` attaches `stream.onTermination = { task.cancel() }` so Task cancellation kills the URLSession task even if the SSE reader is blocked on a half-open TCP socket. `URLError.cancelled` is always mapped to `.cancelled`, never `.unknown` — this is the difference between "Cancelled." and "Something went wrong." in the UI.

### Edge cases

- **Keychain locked at launch** (`errSecInteractionNotAllowed`) — `CredentialStore.load()` returns `nil`; `ProviderSelector` returns `.apiKeyMissing`. Scene-phase re-check handles it on next unlock.
- **Pasted key doesn't match `sk-ant-` prefix** — soft inline warning, save allowed anyway.
- **App Group defaults reset** (uninstall/reinstall) — `optInAccepted` defaults to `false`, disclosure toggle is shown again.

### Telemetry

No error telemetry ships anywhere. `os_log` entries for debugging are local, with `.sensitive` privacy qualifiers on any user text. The existing "no tracking" guarantee remains intact.

## Testing

### EnhancerCoreTests additions (pure unit, no network)

- `AnthropicTransportTests` with a `URLProtocol` stub: happy path delta parsing, each error mapping row from the Error handling section, cancellation propagation, request-body shape assertion (system/messages/stream/model/headers).
- `CloudLanguageModelProviderTests` with a fake `StreamingChatTransport`: availability truth table, 1:1 delta forwarding, error mapping composition.
- `SSEStreamTests`: event/data pair parsing, multi-line data frames, empty-data lines, malformed-line robustness.

### CredentialStoreTests (new SPM package target)

- Gated with `@Suite(.enabled(if: CredentialStore.isKeychainAvailable))`.
- Round-trip save→load→clear; overwrite; second-instance cross-read simulating extension access.

### TalkNativeTests additions

- `ProviderSelectorTests` covering the `ProviderSelector` selection table.
- Extend `AppFlowTests` with one cloud-branch end-to-end flow using `StubLanguageModelProvider` wired through the cloud construction path.

### TalkNativeUITests additions

Two new suites, driven by launch arguments `UI_TESTING_CLOUD=1` and `UI_TESTING_AVAILABILITY=<reason>`. These cause `AppServices.makeStubbed` to inject a stub provider behind the cloud codepath so accessibility IDs match without touching the network.

- `CloudFallbackSettingsUITests` — paste/save/clear key; masked display; opt-in toggle; "Test connection".
- `UnsupportedDeviceCloudCTAUITests` — `.apiKeyMissing` branch renders the CTA and deep-links to `CloudFallbackSettingsView`.

### DeviceSmokeTests additions

- `CloudProviderSmokeTests` suite gated with `@Test(.enabled(if: hasKey))` where `hasKey` reads `ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY_SMOKE"]`.
- 5 representative inputs matching the existing Foundation Models smoke coverage.
- Runs against the real Anthropic API; small per-run cost.

### CI changes

- Existing macos-26 / Xcode 26.4 matrix stays unchanged for unit + UI tests (all new unit tests are pure SPM).
- New optional `cloud-smoke` job: `workflow_dispatch` trigger only, plus conditional on repo secret `ANTHROPIC_API_KEY_SMOKE` being present. Does not run on PRs from forks.

### Explicitly not tested

- Live Anthropic endpoint in unit tests (covered by opt-in smoke suite).
- Real host-app ↔ extension Keychain sharing in CI (covered by manual acceptance).
- SwiftUI snapshot tests (not part of this codebase today; scope creep).

## Privacy and disclosure

### Copy changes

`TalkNative/Settings/AboutView.swift:12` — current copy:
> "All processing runs on your device using Apple Intelligence. No accounts, no network, no tracking."

New copy (two-paragraph form):
> "On iPhone 15 Pro, iPhone 16 and newer, and iPads with M1 or newer, all processing runs on your device using Apple Intelligence. No accounts, no network, no tracking.
>
> On earlier devices, TalkNative can optionally use Anthropic's Claude API with an API key you provide. In that mode, text you enhance is sent to Anthropic's servers. You can add or remove the key in Settings at any time."

`TalkNative/Settings/PrivacyView.swift` — extend with a section titled "Cloud fallback" that restates the above and specifies: key is stored in iOS Keychain, never transmitted anywhere except as the `x-api-key` header to `api.anthropic.com`, not synced via iCloud.

### In-app disclosure

`CloudFallbackSettingsView` Disclosure section shows:
> "Using cloud fallback sends the text you enhance to Anthropic's servers over HTTPS. Nothing else is sent. Your key is stored in the device keychain and never leaves the device except as an authentication header to Anthropic.
>
> Apple Intelligence users stay on-device."

with a toggle `cloud.optIn` that must be on for the provider to report `.available`.

## Rollout plan

1. Add `CredentialStore` package. Unit tests.
2. Add `StreamingChatTransport`, `AnthropicTransport`, `SSEStream` in `EnhancerCore`. Unit tests.
3. Add `CloudLanguageModelProvider` in `EnhancerCore`. Unit tests.
4. Extend `LanguageModelAvailability.Reason`. Update `UnsupportedDeviceView`. Adjust `EnhancerError` messages.
5. Add `ProviderSelector` in `TalkNative`. Update `AppServices.makeProduction` to async. Update `TalkNativeApp` bootstrap. Unit tests.
6. Add `CloudFallbackSettingsView`. Wire into Settings. UI tests.
7. Update entitlements and `project.yml`. Regenerate Xcode project.
8. Update `AboutView` + `PrivacyView` copy.
9. Register URL scheme + add extension open-host-app fallback.
10. Add `DeviceSmokeTests` cloud suite. Update CI workflow for optional cloud-smoke job.
11. Update the README to mention both tiers and the BYOK setup flow.

## Acceptance checklist

Manual, on real hardware:

- Install on iPhone 13 Pro (A15) — `UnsupportedDeviceView` shows "Set up cloud fallback" CTA.
- Tap CTA → `CloudFallbackSettingsView` appears. Paste a valid Anthropic key → save → accept disclosure toggle → main app UI becomes available.
- Enhance a short input — three streamed results appear, one per active preset.
- Cancel mid-enhancement — UI shows "Cancelled.", no "Something went wrong."
- Turn device Airplane Mode on → try to enhance → unsupported-device view with `.networkUnavailable` copy.
- Share extension from Safari — shares text, gets prompted to open host app if opt-in not accepted; after accepting, enhancement works from extension.
- Clear key in Settings → UI returns to CTA state immediately.
- Install on iPhone 16 (A18) — cloud settings section is absent; experience is identical to today.

## Open questions

None. All trade-offs resolved during brainstorming.
