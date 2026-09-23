import XCTest

final class CloudConsentUITests: XCTestCase {
    func testConsentUnlocksAppAndCanBeRevoked() {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer", "-simulateIneligibleDevice"]
        app.launch()

        let allow = app.buttons["cloud.consent.allow"]
        XCTAssertTrue(allow.waitForExistence(timeout: 5))
        allow.tap()

        XCTAssertTrue(app.buttons["EnhanceButton"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        let toggle = app.switches["cloud.consent.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.tap()

        XCTAssertTrue(app.buttons["cloud.consent.allow"].waitForExistence(timeout: 5))
    }

    func testEligibleDeviceShowsNoCloudToggle() {
        let app = XCUIApplication()
        app.launchArguments = ["-useStubEnhancer"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        XCTAssertFalse(app.switches["cloud.consent.toggle"].waitForExistence(timeout: 2))
    }
}
