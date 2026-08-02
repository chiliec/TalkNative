import XCTest

final class KeyboardPanelUITests: XCTestCase {
    private func launchPanel(scenario: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-showKeyboardPanel"]
        if let scenario {
            app.launchEnvironment["TALKNATIVE_KEYBOARD_SCENARIO"] = scenario
        }
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

    // MARK: - Before-cursor path (checklist item 5)

    /// The type-then-tap path, with nothing selected. It renders identically to
    /// the selection path but reaches the panel through a `.contextBefore`
    /// capture, which nothing else exercises through the real view.
    func testBeforeCursorTextReplaceShowsUndo() {
        let app = launchPanel(scenario: "beforeCursorReplace")

        let useButton = app.buttons["Use"].firstMatch
        XCTAssertTrue(useButton.waitForExistence(timeout: 10))
        useButton.tap()

        XCTAssertTrue(
            app.otherElements["keyboardPanel.replacedConfirmation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["keyboardPanel.undo"].exists)
    }

    // MARK: - Non-actionable states offer no replacement

    /// Empty field (checklist items 2/5 setup): the prompt to type, and no
    /// variant to tap.
    func testEmptyFieldShowsNeedsTextMessageAndNoVariants() {
        let app = launchPanel(scenario: "needsText")

        XCTAssertTrue(app.staticTexts["keyboardPanel.needsText"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Use"].firstMatch.exists)
    }

    /// Over-long selection (checklist item 8): the limit message shows and,
    /// crucially, no variant is offered — nothing can be replaced.
    func testLongSelectionShowsLimitMessageAndOffersNoReplacement() {
        let app = launchPanel(scenario: "selectionTooLong")

        XCTAssertTrue(
            app.staticTexts["keyboardPanel.selectionTooLong"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Use"].firstMatch.exists)
    }

    /// Apple Intelligence off: the unavailable message shows and no variant is
    /// offered. Not on the device checklist directly, but the same view path.
    func testUnavailableShowsMessageAndNoVariants() {
        let app = launchPanel(scenario: "unavailable")

        XCTAssertTrue(app.staticTexts["keyboardPanel.unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Use"].firstMatch.exists)
    }

    // MARK: - Full Access prompt (checklist item 2)

    /// Without Full Access the prompt row is shown, and variants still generate
    /// from the built-in presets underneath it.
    func testFullAccessPromptShownWithoutFullAccess() {
        let app = launchPanel(scenario: "fullAccessPrompt")

        XCTAssertTrue(app.otherElements["keyboardPanel.fullAccessPrompt"].waitForExistence(timeout: 10))
        // Built-in presets still produce a usable variant.
        XCTAssertTrue(app.buttons["Use"].firstMatch.waitForExistence(timeout: 10))
    }

    /// Once dismissed (a flag that persists across loads), the row does not come
    /// back, yet variants still generate. This scenario stands in for the next
    /// keyboard load after the user tapped Dismiss.
    func testFullAccessPromptHiddenOnceDismissed() {
        let app = launchPanel(scenario: "fullAccessDismissed")

        // Wait for the panel to render its variants before asserting absence, so
        // this isn't a vacuous pass against an unrendered hierarchy.
        XCTAssertTrue(app.buttons["Use"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.otherElements["keyboardPanel.fullAccessPrompt"].exists)
    }
}
