import SwiftUI

@main
struct TalkNativeApp: App {
    @State private var services: AppServices = {
        if LaunchArguments.useStubEnhancer {
            return AppServices.makeStubbed()
        }
        return AppServices.makeProduction()
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(services)
        }
    }
}
