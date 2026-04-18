import XCTest

final class EnhanceFlowUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer"]
        app.launch()
        return app
    }

    private func typeInput(_ text: String, into app: XCUIApplication) {
        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        textView.tap()
        textView.typeText(text)
    }

    func testEnhanceButtonPresentsResultSheet() {
        let app = launch()
        typeInput("hey can u send me the docs", into: app)

        let enhance = app.buttons["EnhanceButton"]
        XCTAssertTrue(enhance.isEnabled)
        enhance.tap()

        XCTAssertTrue(app.staticTexts["CASUAL"].waitForExistence(timeout: 5))
    }

    func testEnhanceButtonDisabledWhenInputEmpty() {
        let app = launch()
        let enhance = app.buttons["EnhanceButton"]
        XCTAssertTrue(enhance.waitForExistence(timeout: 5))
        XCTAssertFalse(enhance.isEnabled, "Enhance should be disabled with empty input")
    }

    func testTabNavigationSwitchesToRecent() {
        let app = launch()
        let recentTab = app.tabBars.buttons["Recent"]
        XCTAssertTrue(recentTab.waitForExistence(timeout: 5))
        recentTab.tap()
        XCTAssertTrue(app.staticTexts["No recent enhancements"].waitForExistence(timeout: 3))
    }

    func testSettingsTabReachesActivePresets() {
        let app = launch()
        let settingsTab = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5))
        settingsTab.tap()

        let activePresetsCell = app.staticTexts["Active presets"]
        XCTAssertTrue(activePresetsCell.waitForExistence(timeout: 3))
        activePresetsCell.tap()

        let navBar = app.navigationBars["Active presets"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 3))
    }

    func testResultSheetShowsAllThreeVariantLabels() {
        let app = launch()
        typeInput("see you later", into: app)

        app.buttons["EnhanceButton"].tap()

        XCTAssertTrue(app.staticTexts["CASUAL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["PROFESSIONAL"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["WARM"].waitForExistence(timeout: 5))
    }

    func testUnsupportedDeviceCopyDoesNotRenderWhenStubEnabled() {
        let app = launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Apple Intelligence required"].exists)
    }

    func testResultSheetDoneButtonDismisses() {
        let app = launch()
        typeInput("test", into: app)
        app.buttons["EnhanceButton"].tap()

        XCTAssertTrue(app.staticTexts["CASUAL"].waitForExistence(timeout: 5))
        let doneButton = app.navigationBars.buttons["Done"].firstMatch
        XCTAssertTrue(doneButton.exists)
        doneButton.tap()

        XCTAssertTrue(app.buttons["EnhanceButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["CASUAL"].exists)
    }
}
