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
    /// the real `KeyboardPanel` is hosted here over a stub proxy instead. The
    /// scenario selects the panel's starting state — see `KeyboardHarnessScenario`.
    private var keyboardPanelHarness: some View {
        let scenario = KeyboardHarnessScenario(LaunchArguments.keyboardScenario)
        return KeyboardPanel(
            viewModel: KeyboardPanelViewModel(
                proxy: scenario.makeProxy(),
                enhancement: EnhancementViewModel(
                    enhancer: Enhancer(
                        provider: StubLanguageModelProvider(
                            availability: scenario.availability,
                            scriptedChunks: ["I went to the store and bought some milk."]))),
                availability: { scenario.availability },
                activePresets: services.presetStore.activePresets,
                hasFullAccess: scenario.hasFullAccess
            ),
            isFullAccessPromptDismissed: scenario.isFullAccessPromptDismissed,
            // A no-op, matching the real controller: dismissing persists a flag
            // read on the next load, so the row does not disappear in-session.
            // The `fullAccessDismissed` scenario stands in for that next load.
            onDismissFullAccessPrompt: {}
        )
    }
}

/// The starting configurations the `-showKeyboardPanel` harness can be launched
/// into, one per panel state XCUITest needs to reach.
private enum KeyboardHarnessScenario {
    /// Text selected, model available, Full Access granted — the default.
    case selectionReplace
    /// Text before the cursor, nothing selected — the type-then-tap path.
    case beforeCursorReplace
    /// Empty field.
    case needsText
    /// A selection past the 2000-character ceiling.
    case selectionTooLong
    /// No Full Access, prompt not yet dismissed — the row is shown.
    case fullAccessPrompt
    /// No Full Access, prompt already dismissed — the row is hidden.
    case fullAccessDismissed
    /// Apple Intelligence off.
    case unavailable

    init(_ raw: String?) {
        switch raw {
        case "beforeCursorReplace": self = .beforeCursorReplace
        case "needsText": self = .needsText
        case "selectionTooLong": self = .selectionTooLong
        case "fullAccessPrompt": self = .fullAccessPrompt
        case "fullAccessDismissed": self = .fullAccessDismissed
        case "unavailable": self = .unavailable
        default: self = .selectionReplace
        }
    }

    private static let draft = "i has went to the store and buyed some milks"

    func makeProxy() -> StubTextDocumentProxy {
        switch self {
        case .selectionReplace:
            return StubTextDocumentProxy(
                before: "i has went to the store ", selected: "and buyed some milks", after: "")
        case .beforeCursorReplace, .fullAccessPrompt, .fullAccessDismissed:
            return StubTextDocumentProxy(before: Self.draft)
        case .needsText, .unavailable:
            return StubTextDocumentProxy()
        case .selectionTooLong:
            return StubTextDocumentProxy(selected: String(repeating: "z", count: 2001))
        }
    }

    var availability: LanguageModelAvailability {
        if case .unavailable = self { return .unavailable(.appleIntelligenceNotEnabled) }
        return .available
    }

    var hasFullAccess: Bool {
        switch self {
        case .fullAccessPrompt, .fullAccessDismissed: return false
        default: return true
        }
    }

    var isFullAccessPromptDismissed: Bool {
        switch self {
        case .fullAccessPrompt: return false
        default: return true
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
