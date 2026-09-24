import Testing
@testable import SwipeSortEngine

/// Go, no-go: hold items must be left alone.
@Suite struct RunStateHoldTests {
    static var allHolds: ContentPack {
        var pack = ContentPack.shapesAndColours
        pack.holdProbability = 0.9
        return pack
    }

    /// A harness on a pack where nearly every item is a hold, advanced until a hold item is on screen.
    func harnessOnHoldItem() -> RunHarness {
        var h = RunHarness(seed: 3, pack: Self.allHolds)
        h.startRunAndRound()
        while let active = h.activeItem, !active.isHold {
            h.send(.answer(active.expectedEdge), after: .milliseconds(400))
            h.advanceToNextItem()
        }
        return h
    }

    @Test func plainPacksNeverShowHoldItems() {
        var h = RunHarness()
        h.startRunAndRound()
        for _ in 0..<10 {
            #expect(h.activeItem?.isHold == false)
            h.answerCorrectly()
        }
    }

    @Test func leavingAHoldItemIsCorrectAndScoresWithoutSpeedBonus() {
        var h = harnessOnHoldItem()
        let active = h.activeItem!
        let streakBefore = h.state.streak
        let scoreBefore = h.state.score
        let produced = h.send(.tick, after: active.window)
        #expect(h.state.lives == 3)
        #expect(h.state.streak == streakBefore + 1)
        let expectedPoints = h.state.configuration.scoring.pointsForHold(streak: streakBefore + 1)
        #expect(h.state.score == scoreBefore + expectedPoints)
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(outcome == .held(points: expectedPoints, streak: streakBefore + 1))
        #expect(result.hold)
        #expect(result.correct)
        #expect(!result.timedOut)
        #expect(result.reaction == nil)
        #expect(result.answeredCategoryID == nil)
        #expect(produced.contains(.scoreChanged(h.state.score)))
        #expect(produced.contains { if case .feedback(.correct) = $0 { true } else if case .feedback(.streakMilestone) = $0 { true } else { false } })
    }

    @Test func flickingAHoldItemIsAFalseAlarm() {
        var h = harnessOnHoldItem()
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(300))
        #expect(h.state.lives == 2)
        #expect(h.state.streak == 0)
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(outcome == .falseAlarm)
        #expect(result.hold)
        #expect(!result.correct)
        #expect(!result.timedOut)
        #expect(result.reaction == .milliseconds(300))
        #expect(result.points == 0)
        #expect(h.contains(.wrong, in: produced))
        #expect(produced.contains(.livesChanged(2)))
    }

    @Test func statisticsCountHoldsAndFalseAlarms() {
        var h = harnessOnHoldItem()
        let active = h.activeItem!
        h.send(.answer(active.expectedEdge), after: .milliseconds(300))
        h.advanceToNextItem()
        while let next = h.activeItem, !next.isHold {
            h.send(.answer(next.expectedEdge), after: .milliseconds(400))
            h.advanceToNextItem()
        }
        if let held = h.activeItem {
            h.send(.tick, after: held.window)
        }
        h.finishRoundByClock()
        let stats = RunStatistics.compute(rounds: h.state.completedRounds)
        #expect(stats.holdCount == 2)
        #expect(stats.falseAlarmCount == 1)
        #expect(stats.falseAlarmRate == 0.5)
        #expect(stats.wrongSwipeCount == 0, "a false alarm is not a wrong swipe")
        #expect(stats.timeoutCount == 0, "a held item is not a timeout")
        #expect(stats.confusionPairs.isEmpty)
    }
}
