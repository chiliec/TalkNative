import XCTest

/// Captures App Store screenshots into `$SCREENSHOT_DIR`. Skipped unless that
/// variable is set on the runner (`TEST_RUNNER_SCREENSHOT_DIR=... xcodebuild test`),
/// so CI never runs it. Use the `(screenshots)` simulators with the status bar
/// overridden via `simctl status_bar`.
final class ScreenshotTests: XCTestCase {
    private static let input =
        "hi, i wanted to ask if you could send me the documents until friday? i have deadline on monday and it will be very helpful for me"
    private static let responses = [
        "Hey, could you send me the documents by Friday? I've got a deadline on Monday, so that would really help.",
        "Hello, could you please send me the documents by Friday? I have a deadline on Monday, and receiving them in advance would be very helpful.",
        "Hi! Would you mind sending me the documents by Friday? My deadline is Monday, and having them early would help me a lot. Thank you!",
    ]
    private static let keyboardResponses = [
        "I went to the store and grabbed some milk.",
        "I went to the store and bought some milk.",
        "I popped over to the store and picked up some milk.",
    ]

    private var directory: URL!

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else {
            throw XCTSkip("SCREENSHOT_DIR not set")
        }
        directory = URL(fileURLWithPath: dir)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String], env: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launchEnvironment = env
        app.launch()
        return app
    }

    /// XCUITest rejects string identifiers over 128 characters, so match by prefix.
    private func text(startingWith prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", String(prefix.prefix(40)))).firstMatch
    }

    private func snap(_ name: String) throws {
        // Let animations settle before capturing.
        Thread.sleep(forTimeInterval: 1)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try png.write(to: directory.appendingPathComponent("\(name).png"))
    }

    func testEnhanceResults() throws {
        let app = launch(
            ["-useStubEnhancer"],
            env: [
                "TALKNATIVE_PREFILL_INPUT": Self.input,
                "TALKNATIVE_STUB_RESPONSES": Self.responses.joined(separator: "|"),
            ])
        let enhance = app.buttons["EnhanceButton"]
        XCTAssertTrue(enhance.waitForExistence(timeout: 10))
        try snap("01-enhance-input")
        enhance.tap()
        XCTAssertTrue(text(startingWith: Self.responses[2], in: app).waitForExistence(timeout: 10))
        try snap("02-enhance-results")
    }

    func testKeyboardPanel() throws {
        let app = launch(
            ["-showKeyboardPanel"],
            env: ["TALKNATIVE_STUB_RESPONSES": Self.keyboardResponses.joined(separator: "|")])
        XCTAssertTrue(text(startingWith: Self.keyboardResponses[2], in: app).waitForExistence(timeout: 10))
        try snap("03-keyboard-variants")
        app.buttons["Use"].firstMatch.tap()
        XCTAssertTrue(app.buttons["keyboardPanel.undo"].waitForExistence(timeout: 5))
        try snap("04-keyboard-replaced")
    }

    func testSettingsScreens() throws {
        let app = launch(["-useStubEnhancer"])
        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()
        try snap("05-settings")
        app.staticTexts["Active presets"].tap()
        XCTAssertTrue(app.navigationBars["Active presets"].waitForExistence(timeout: 5))
        try snap("06-presets")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.staticTexts["Privacy"].tap()
        Thread.sleep(forTimeInterval: 1)
        try snap("07-privacy")
    }
}
