import XCTest

// nonisolated: the app target defaults to main-actor isolation, but XCTestCase initialisers are nonisolated.
nonisolated final class LaunchAndPlayTests: XCTestCase {
    @MainActor
    func testLaunchPlayShowsFirstItem() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        app.buttons["Play"].tap()
        // Round intro auto-starts after 2.5 seconds; the item is the only element with a category label.
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 6), "play screen did not appear")
        pause.tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
    }
}
