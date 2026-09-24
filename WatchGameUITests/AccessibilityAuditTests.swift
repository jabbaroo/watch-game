import XCTest

/// Walks every screen and checks the accessibility structure the spec promises (section 10).
/// Run it a second time on a simulator with Reduce Motion and VoiceOver switched on to cover
/// the settings-dependent paths; UIAccessibility's query API is unavailable on watchOS, so the
/// runner is told what to expect through TEST_RUNNER_A11Y_VOICEOVER=1 and TEST_RUNNER_A11Y_REDUCE_MOTION=1.
nonisolated final class AccessibilityAuditTests: XCTestCase {
    private let categories = ["Red", "Yellow", "Green", "Blue", "Circle", "Square", "Triangle", "Star"]

    @MainActor
    func testEveryScreenIsLabelledWithTapTargetsOn() {
        let app = XCUIApplication()
        app.launchArguments = ["-settings.tapToSort", "YES", "-settings.colourHints", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["play.shapes-colours"].waitForExistence(timeout: 5))
        assertNoUnlabelledControls(app, screen: "home")
        attachHierarchy(app, "home")

        // Settings
        XCTAssertTrue(row(app, "Settings").waitForExistence(timeout: 3), "Settings row must be labelled")
        row(app, "Settings").tap()
        attachHierarchy(app, "settings")
        for name in ["Sounds", "Haptics", "Tap to sort", "Colour hints", "Reset history"] {
            XCTAssertTrue(row(app, name).waitForExistence(timeout: 3), "missing labelled control \(name)")
        }
        assertNoUnlabelledControls(app, screen: "settings")
        app.navigationBars.buttons.firstMatch.tap()

        // History
        XCTAssertTrue(row(app, "History").waitForExistence(timeout: 3), "History row must be labelled")
        row(app, "History").tap()
        XCTAssertTrue(app.staticTexts["Play a run to see it here."].waitForExistence(timeout: 3) || app.staticTexts["Runs"].waitForExistence(timeout: 1))
        assertNoUnlabelledControls(app, screen: "history")
        attachHierarchy(app, "history")
        app.navigationBars.buttons.firstMatch.tap()

        // Play with tap targets: the item is labelled with its category, each active edge is a button.
        XCTAssertTrue(homeIsShowing(app), "Home should scroll back to the first game")
        app.buttons["play.shapes-colours"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 6), "play screen did not appear")
        let sortButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sort as '"))
        XCTAssertEqual(sortButtons.count, 2, "round 1 has two categories, so two tap targets")
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", categories)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3), "the item must announce its category")
        attachHierarchy(app, "play-tap-targets")
        assertNoUnlabelledControls(app, screen: "play")

        // Pause and quit are labelled and reachable.
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Quit run"].exists)
        attachHierarchy(app, "paused")
        app.buttons["Quit run"].tap()
        XCTAssertTrue(app.buttons["Quit"].waitForExistence(timeout: 2))
        app.buttons["Quit"].tap()
        XCTAssertTrue(homeIsShowing(app), "quit returns to Home")
    }

    @MainActor
    func testSwipeOnlyPlayHidesEdgeLabelsFromVoiceOverUnlessVoiceOverRuns() {
        let app = XCUIApplication()
        app.launchArguments = ["-settings.tapToSort", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["play.shapes-colours"].waitForExistence(timeout: 5))
        app.buttons["play.shapes-colours"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 6))
        let sortButtons = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sort as '"))
        if ProcessInfo.processInfo.environment["A11Y_VOICEOVER"] == "1" {
            XCTAssertEqual(sortButtons.count, 2, "VoiceOver forces tap targets on")
        } else {
            XCTAssertEqual(sortButtons.count, 0, "decorative edge labels stay out of the accessibility tree")
        }
        let item = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", categories)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        attachHierarchy(app, "play-swipe-only")
    }

    @MainActor
    func testDailyRunWritesTheWidgetSummaryOnDismissal() {
        let app = XCUIApplication()
        app.launchArguments = ["-settings.tapToSort", "YES"]
        app.launch()
        XCTAssertTrue(row(app, "Daily challenge").waitForExistence(timeout: 5), "Daily row must be labelled")
        row(app, "Daily challenge").tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 6))
        app.buttons["Pause"].tap()
        app.buttons["Quit run"].tap()
        XCTAssertTrue(app.buttons["Quit"].waitForExistence(timeout: 2))
        app.buttons["Quit"].tap()
        XCTAssertTrue(homeIsShowing(app), "quit returns to Home")
        // The summary file is checked from outside the test through the App Group container.
    }

    @MainActor
    func testRunsUnderReduceMotion() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["A11Y_REDUCE_MOTION"] == "1", "run with TEST_RUNNER_A11Y_REDUCE_MOTION=1 on a simulator with Reduce Motion on")
        let app = XCUIApplication()
        app.launchArguments = ["-settings.tapToSort", "YES", "-debugStartRound", "5"]
        app.launch()
        XCTAssertTrue(app.buttons["play.shapes-colours"].waitForExistence(timeout: 5))
        app.buttons["play.shapes-colours"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 6))
        // Let items time out under the crossfade paths; the run must reach Results without hanging or crashing.
        let outOfLives = app.staticTexts["Out of lives in round 5"]
        XCTAssertTrue(outOfLives.waitForExistence(timeout: 20), "three timeouts should end the run on the results screen")
        attachHierarchy(app, "reduce-motion")
    }

    /// Home may be scrolled after a run; scroll back until the first game row is in the tree.
    @MainActor
    private func homeIsShowing(_ app: XCUIApplication) -> Bool {
        let play = app.buttons["play.shapes-colours"]
        var attempts = 0
        while !play.waitForExistence(timeout: 2), attempts < 6 {
            XCUIDevice.shared.rotateDigitalCrown(delta: -1.0)   // scroll back toward the top
            attempts += 1
        }
        return play.exists
    }

    /// A List row, link or button whose accessibility label starts with `label`, whatever element type
    /// watchOS exposes it as. Rows below the fold are not in the tree until scrolled to, so this scrolls.
    @MainActor
    private func row(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        let query = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", label))
        var attempts = 0
        while !query.firstMatch.exists, attempts < 16 {
            // A swipe can land on a toggle and never scroll; the crown always scrolls the list.
            // Small steps: rows leave the accessibility tree as soon as they scroll off screen.
            XCUIDevice.shared.rotateDigitalCrown(delta: 0.25)
            attempts += 1
        }
        return query.firstMatch
    }

    @MainActor
    private func assertNoUnlabelledControls(_ app: XCUIApplication, screen: String) {
        for element in app.descendants(matching: .button).allElementsBoundByIndex where element.isHittable {
            XCTAssertFalse(element.label.isEmpty && element.identifier.isEmpty, "\(screen): unlabelled button")
        }
    }

    @MainActor
    private func attachHierarchy(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(string: app.debugDescription)
        attachment.name = "hierarchy-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
