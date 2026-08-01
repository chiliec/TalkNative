import XCTest

final class KeyboardPanelUITests: XCTestCase {
    private func launchPanel() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-showKeyboardPanel"]
        app.launch()
        return app
    }

    func testVariantRowAppearsAndReplaceShowsUndo() {
        let app = launchPanel()

        let useButton = app.buttons["Use"].firstMatch
        XCTAssertTrue(useButton.waitForExistence(timeout: 10))

        useButton.tap()

        let confirmation = app.otherElements["keyboardPanel.replacedConfirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keyboardPanel.undo"].exists)
    }

    func testUndoReturnsToVariantList() {
        let app = launchPanel()

        let useButton = app.buttons["Use"].firstMatch
        XCTAssertTrue(useButton.waitForExistence(timeout: 10))
        useButton.tap()

        let undo = app.buttons["keyboardPanel.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5))
        undo.tap()

        XCTAssertFalse(app.otherElements["keyboardPanel.replacedConfirmation"].exists)
        XCTAssertTrue(app.buttons["Use"].firstMatch.isEnabled)
    }
}
