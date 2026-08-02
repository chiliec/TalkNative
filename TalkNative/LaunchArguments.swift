import Foundation

enum LaunchArguments {
    static let useStubEnhancerFlag = "-useStubEnhancer"
    static let showKeyboardPanelFlag = "-showKeyboardPanel"
    static let prefillInputEnvKey = "TALKNATIVE_PREFILL_INPUT"
    static let keyboardScenarioEnvKey = "TALKNATIVE_KEYBOARD_SCENARIO"

    static var useStubEnhancer: Bool {
        CommandLine.arguments.contains(useStubEnhancerFlag)
    }

    static var showKeyboardPanel: Bool {
        CommandLine.arguments.contains(showKeyboardPanelFlag)
    }

    static var prefilledInput: String? {
        ProcessInfo.processInfo.environment[prefillInputEnvKey]
    }

    /// Selects which state the `-showKeyboardPanel` harness starts in, so
    /// XCUITest can reach panel states the default selection scenario can't —
    /// the empty field, an over-long selection, the Full Access prompt, and the
    /// unavailable message. Absent means the default selection-replace scenario.
    static var keyboardScenario: String? {
        ProcessInfo.processInfo.environment[keyboardScenarioEnvKey]
    }
}
