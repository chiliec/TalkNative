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
