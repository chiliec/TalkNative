import XCTest

final class EnhanceFlowUITests: XCTestCase {
    func testEnhanceButtonPresentsResultSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer"]
        app.launch()

        let textView = app.textViews.firstMatch
        XCTAssertTrue(textView.waitForExistence(timeout: 5))
        textView.tap()
        textView.typeText("hey can u send me the docs")

        let enhance = app.buttons["Enhance"]
        XCTAssertTrue(enhance.isEnabled)
        enhance.tap()

        let casualLabel = app.staticTexts["CASUAL"]
        XCTAssertTrue(casualLabel.waitForExistence(timeout: 5))
    }
}
