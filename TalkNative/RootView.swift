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
                availability: { .available },
                activePresets: services.presetStore.activePresets,
                hasFullAccess: true
            ),
            isFullAccessPromptDismissed: true,
            onDismissFullAccessPrompt: {}
        )
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
