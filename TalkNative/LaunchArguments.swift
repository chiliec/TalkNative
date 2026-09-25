import Foundation
import PresetKit

enum LaunchArguments {
    static let useStubEnhancerFlag = "-useStubEnhancer"
    static let showKeyboardPanelFlag = "-showKeyboardPanel"
    static let simulateIneligibleDeviceFlag = "-simulateIneligibleDevice"
    static let prefillInputEnvKey = "TALKNATIVE_PREFILL_INPUT"
    static let keyboardScenarioEnvKey = "TALKNATIVE_KEYBOARD_SCENARIO"
    static let stubResponsesEnvKey = "TALKNATIVE_STUB_RESPONSES"

    static var useStubEnhancer: Bool {
        CommandLine.arguments.contains(useStubEnhancerFlag)
    }

    /// With `-useStubEnhancer`: behave like an iPhone without Apple
    /// Intelligence so the cloud consent flow is reachable without a network.
    static var simulateIneligibleDevice: Bool {
        CommandLine.arguments.contains(simulateIneligibleDeviceFlag)
    }

    static var showKeyboardPanel: Bool {
        CommandLine.arguments.contains(showKeyboardPanelFlag)
    }

    static var prefilledInput: String? {
        ProcessInfo.processInfo.environment[prefillInputEnvKey]
    }

    /// With `-useStubEnhancer` or `-showKeyboardPanel`: `|`-separated texts the
    /// stub returns for the active presets, in order. Used for screenshots.
    static func stubResponses(for presets: [Preset]) -> [String: [String]] {
        guard let raw = ProcessInfo.processInfo.environment[stubResponsesEnvKey] else { return [:] }
        let texts = raw.components(separatedBy: "|")
        return Dictionary(uniqueKeysWithValues: zip(presets.map(\.instructions), texts.map { [$0] }))
    }

    /// Selects which state the `-showKeyboardPanel` harness starts in, so
    /// XCUITest can reach panel states the default selection scenario can't —
    /// the empty field, an over-long selection, the Full Access prompt, and the
    /// unavailable message. Absent means the default selection-replace scenario.
    static var keyboardScenario: String? {
        ProcessInfo.processInfo.environment[keyboardScenarioEnvKey]
    }
}
