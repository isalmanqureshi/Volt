import XCTest

final class VoltUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testTabsExist() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Watchlist"].exists)
        XCTAssertTrue(app.tabBars.buttons["Portfolio"].exists)
        XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
    }
}
