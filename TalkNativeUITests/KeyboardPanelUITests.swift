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

        // Waited for, not sampled: `tap()` returns once the event is delivered,
        // before SwiftUI has re-rendered `.ready`, so a bare `exists` reads the
        // stale `.replaced` hierarchy and fails on a loaded machine.
        XCTAssertTrue(
            app.otherElements["keyboardPanel.replacedConfirmation"].waitForNonExistence(timeout: 5))
        let enabledAgain = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == true"),
            object: app.buttons["Use"].firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [enabledAgain], timeout: 5), .completed)
    }
}
