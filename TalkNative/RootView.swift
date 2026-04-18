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
