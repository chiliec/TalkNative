import Foundation

enum LaunchArguments {
    static let useStubEnhancerFlag = "-useStubEnhancer"
    static let prefillInputEnvKey = "TALKNATIVE_PREFILL_INPUT"

    static var useStubEnhancer: Bool {
        CommandLine.arguments.contains(useStubEnhancerFlag)
    }

    static var prefilledInput: String? {
        ProcessInfo.processInfo.environment[prefillInputEnvKey]
    }
}
