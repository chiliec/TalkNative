import SwiftUI

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
            RootView()
                .environment(services)
        }
    }
}
