import Testing
@testable import SwipeSortEngine

@Suite struct RunConfigurationTests {
    let config = RunConfiguration.standard

    @Test func standardValuesMatchSpec() {
        #expect(config.roundCount == 8)
        #expect(config.roundDuration == .seconds(40))
        #expect(config.baseWindows.count == 8)
        #expect(config.firstItemGrace == .seconds(1))
        #expect(config.startingLives == 3)
        #expect(config.maximumLives == 3)
        #expect(config.categoryRamp == [2, 2, 3, 3, 4, 4, 4, 4])
    }

    @Test func windowFallsPerRound() {
        let expected = [2000, 1900, 1750, 1600, 1450, 1300, 1150, 1000]
        for (round, milliseconds) in expected.enumerated() {
            #expect(config.itemWindow(roundIndex: round, streak: 0) == .milliseconds(milliseconds), "round \(round)")
        }
        #expect(config.itemWindow(roundIndex: 9, streak: 0) == .seconds(1), "rounds past the table reuse the last window")
    }

    @Test func windowTrimsEveryFiveStreakUpToCap() {
        #expect(config.itemWindow(roundIndex: 0, streak: 4) == .seconds(2))
        #expect(config.itemWindow(roundIndex: 0, streak: 5) == .milliseconds(1950))
        #expect(config.itemWindow(roundIndex: 0, streak: 10) == .milliseconds(1900))
        #expect(config.itemWindow(roundIndex: 0, streak: 20) == .milliseconds(1800))
        #expect(config.itemWindow(roundIndex: 0, streak: 100) == .milliseconds(1800))
    }

    @Test func windowNeverDropsBelowFloor() {
        #expect(config.itemWindow(roundIndex: 7, streak: 30) == .milliseconds(850))
        #expect(config.itemWindow(roundIndex: 7, streak: 0) == .seconds(1))
    }

    @Test func firstItemOfARoundGetsGrace() {
        #expect(config.itemWindow(roundIndex: 0, streak: 0, isFirstItem: true) == .seconds(3))
        #expect(config.itemWindow(roundIndex: 7, streak: 0, isFirstItem: true) == .seconds(2))
        #expect(config.itemWindow(roundIndex: 0, streak: 5, isFirstItem: true) == .milliseconds(2950))
    }

    @Test func categoryCountFollowsRampAndRepeatsLastValue() {
        #expect((0..<8).map { config.categoryCount(roundIndex: $0) } == [2, 2, 3, 3, 4, 4, 4, 4])
        #expect(config.categoryCount(roundIndex: 12) == 4)
    }

    @Test func streakKnobsAgree() {
        // Spec 3.4: window trim, milestone haptic and multiplier all align on the same streak step.
        #expect(config.streakStep == 5)
        #expect(config.scoring.multiplierStep == config.streakStep)
    }
}
