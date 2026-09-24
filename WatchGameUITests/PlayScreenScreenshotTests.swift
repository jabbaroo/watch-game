import XCTest

/// Captures the play screen for the layout pass. Run per device with
/// `-only-testing:WatchGameUITests/PlayScreenScreenshotTests`, then export the
/// attachments with `xcrun xcresulttool export attachments`.
nonisolated final class PlayScreenScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureFourEdgeRoundWithTapTargets() {
        capture(named: "play-4edges-tap", launchArguments: ["-settings.tapToSort", "YES", "-debugStartRound", "5"])
    }

    @MainActor
    func testCaptureFourEdgeRoundSwipeOnly() {
        capture(named: "play-4edges-swipe", launchArguments: ["-settings.tapToSort", "NO", "-debugStartRound", "5"])
    }

    @MainActor
    private func capture(named name: String, launchArguments: [String]) {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        attach("home", app)
        app.buttons["Play"].tap()
        attach("round-intro", app)
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 6), "play screen did not appear")
        attach(name, app)
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
        attach("paused", app)
    }

    @MainActor
    private func attach(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
