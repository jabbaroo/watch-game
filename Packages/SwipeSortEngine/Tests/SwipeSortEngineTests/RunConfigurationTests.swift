import Testing
@testable import SwipeSortEngine

@Suite struct RunConfigurationTests {
    let config = RunConfiguration.standard

    @Test func standardValuesMatchSpec() {
        #expect(config.roundCount == 8)
        #expect(config.roundDuration == .seconds(45))
        #expect(config.startingLives == 3)
        #expect(config.maximumLives == 3)
        #expect(config.categoryRamp == [2, 2, 3, 3, 4, 4, 4, 4])
    }

    @Test func windowFallsPerRound() {
        #expect(config.itemWindow(roundIndex: 0, streak: 0) == .seconds(2))
        #expect(config.itemWindow(roundIndex: 1, streak: 0) == .milliseconds(1850))
        #expect(config.itemWindow(roundIndex: 7, streak: 0) == .milliseconds(950))
    }

    @Test func windowTrimsEveryFiveStreakUpToCap() {
        #expect(config.itemWindow(roundIndex: 0, streak: 4) == .seconds(2))
        #expect(config.itemWindow(roundIndex: 0, streak: 5) == .milliseconds(1950))
        #expect(config.itemWindow(roundIndex: 0, streak: 10) == .milliseconds(1900))
        #expect(config.itemWindow(roundIndex: 0, streak: 30) == .milliseconds(1700))
        #expect(config.itemWindow(roundIndex: 0, streak: 100) == .milliseconds(1700))
    }

    @Test func windowNeverDropsBelowFloor() {
        #expect(config.itemWindow(roundIndex: 7, streak: 30) == .milliseconds(800))
        #expect(config.itemWindow(roundIndex: 20, streak: 0) == .milliseconds(800))
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
