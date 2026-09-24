import Testing
@testable import SwipeSortEngine

@Suite struct RunStateTests {
    @Test func startRunEntersFirstRoundIntro() {
        var h = RunHarness()
        let produced = h.send(.startRun)
        #expect(h.state.phase == .roundIntro(h.state.plans[0]))
        #expect(produced == [.roundIntro(h.state.plans[0])])
        #expect(h.state.lives == 3)
        #expect(h.state.score == 0)
    }

    @Test func startRoundShowsFirstItemWithFullWindow() throws {
        var h = RunHarness()
        h.send(.startRun)
        let produced = h.send(.startRound, after: .seconds(1))
        let active = try #require(h.activeItem)
        #expect(active.index == 0)
        #expect(active.window == .seconds(2))
        #expect(active.shownAt == .seconds(1))
        #expect(active.deadline == .seconds(3))
        #expect(active.expectedEdge == h.state.currentPlan.mapping.edge(for: active.expectedCategoryID))
        #expect(produced.contains(.roundStarted(h.state.plans[0])))
        #expect(h.contains(.roundStarted, in: produced))
        #expect(produced.contains(.itemShown(active)))
        #expect(produced.contains(.wake(at: .seconds(3))))
    }

    @Test func correctAnswerScoresAndMovesToGap() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(500))
        // 100 x 1 + speed bonus 50 x (1.5 / 2.0) = 137.5, rounded to 138
        #expect(h.state.score == 138)
        #expect(h.state.streak == 1)
        #expect(h.state.lives == 3)
        #expect(h.state.phase == .betweenItems(nextItemAt: .milliseconds(750)))
        #expect(produced.contains(.scoreChanged(138)))
        #expect(h.contains(.correct(streak: 1), in: produced))
        #expect(produced.contains(.wake(at: .milliseconds(750))))
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.correct)
        #expect(result.points == 138)
        #expect(result.reaction == .milliseconds(500))
        #expect(result.answeredCategoryID == active.expectedCategoryID)
        #expect(outcome == .correct(points: 138, streak: 1))
    }

    @Test func wrongAnswerCostsALifeAndResetsStreak() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        let active = h.activeItem!
        let wrongEdge = h.state.currentPlan.mapping.edges.first { $0 != active.expectedEdge }!
        let produced = h.send(.answer(wrongEdge), after: .milliseconds(300))
        #expect(h.state.lives == 2)
        #expect(h.state.streak == 0)
        #expect(produced.contains(.livesChanged(2)))
        #expect(h.contains(.wrong, in: produced))
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(!result.correct)
        #expect(!result.timedOut)
        #expect(result.points == 0)
        #expect(result.answeredCategoryID == h.state.currentPlan.mapping.category(at: wrongEdge))
        #expect(outcome == .wrong)
    }

    @Test func timeoutCostsALife() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.tick, after: active.window)
        #expect(h.state.lives == 2)
        #expect(h.contains(.timedOut, in: produced))
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.timedOut)
        #expect(result.reaction == nil)
        #expect(result.answeredCategoryID == nil)
        #expect(outcome == .timedOut)
    }

    @Test func answerAtOrAfterDeadlineIsATimeout() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: active.window)
        #expect(h.state.lives == 2)
        #expect(h.contains(.timedOut, in: produced))
        guard case .itemResolved(let result, _) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.timedOut)
        #expect(result.answeredCategoryID == nil)
    }

    @Test func tickBeforeDeadlineOnlyReschedules() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.tick, after: .milliseconds(100))
        #expect(produced == [.wake(at: active.deadline)])
        #expect(h.activeItem == active)
        #expect(h.state.lives == 3)
    }

    @Test func flickToUnmappedEdgeIsIgnored() {
        var h = RunHarness()
        h.startRunAndRound()
        #expect(h.state.currentPlan.mapping.edges == [.left, .right])
        let active = h.activeItem!
        let produced = h.send(.answer(.up), after: .milliseconds(100))
        #expect(produced == [.wake(at: active.deadline)])
        #expect(h.activeItem == active)
        #expect(h.state.lives == 3)
        #expect(h.state.currentRoundItems.isEmpty)
    }

    @Test func threeErrorsEndTheRunOutOfLives() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerWrong()
        h.answerWrong()
        let produced = h.send(.tick, after: h.activeItem!.window)
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .outOfLives)
        #expect(summary.completed)
        #expect(summary.rounds.count == 1)
        #expect(summary.rounds[0].cutShort)
        #expect(!summary.rounds[0].perfect)
        #expect(summary.rounds[0].items.count == 3)
        #expect(summary.roundsCompleted == 0)
        #expect(summary.livesRemaining == 0)
        #expect(produced.contains(.runEnded(summary)))
        #expect(h.contains(.runEnded, in: produced))
        #expect(!produced.contains(.roundIntro(h.state.plans[1])))
    }

    @Test func roundClockEndsRoundAndDiscardsInFlightItem() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        let produced = h.finishRoundByClock()
        #expect(h.state.phase == .roundIntro(h.state.plans[1]))
        #expect(h.state.completedRounds.count == 1)
        #expect(h.state.completedRounds[0].items.count == 1)
        #expect(!h.state.completedRounds[0].cutShort)
        #expect(produced.contains(.roundIntro(h.state.plans[1])))
        #expect(produced.contains { if case .roundEnded = $0 { true } else { false } })
    }

    @Test func perfectRoundEarnsLifeAndBonus() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerWrong()
        #expect(h.state.lives == 2)
        h.finishRoundByClock()
        h.send(.startRound)
        h.answerCorrectly()
        h.answerCorrectly()
        h.answerCorrectly()
        let scoreBefore = h.state.score
        let produced = h.finishRoundByClock()
        #expect(h.state.lives == 3)
        #expect(h.state.score == scoreBefore + 500)
        #expect(h.contains(.lifeEarned, in: produced))
        #expect(h.contains(.perfectRound, in: produced))
        #expect(h.state.completedRounds[1].perfect)
        #expect(h.state.completedRounds[1].score == h.state.completedRounds[1].items.reduce(500) { $0 + $1.points })
    }

    @Test func perfectRoundAtMaximumLivesGivesBonusButNoLife() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        let produced = h.finishRoundByClock()
        #expect(h.state.lives == 3)
        #expect(h.contains(.perfectRound, in: produced))
        #expect(!h.contains(.lifeEarned, in: produced))
        #expect(!produced.contains(.livesChanged(3)))
    }

    @Test func emptyRoundIsNotPerfect() {
        var h = RunHarness()
        h.startRunAndRound()
        let produced = h.finishRoundByClock()
        #expect(!h.state.completedRounds[0].perfect)
        #expect(!h.contains(.perfectRound, in: produced))
    }

    @Test func streakResetsAtRoundStart() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        h.answerCorrectly()
        h.answerCorrectly()
        #expect(h.state.streak == 3)
        h.finishRoundByClock()
        #expect(h.state.streak == 0)
        h.send(.startRound)
        let active = h.activeItem!
        h.send(.answer(active.expectedEdge), after: .milliseconds(500))
        #expect(h.state.streak == 1)
    }

    @Test func fifthCorrectIsAMilestoneAndScoresDouble() {
        var h = RunHarness()
        h.startRunAndRound()
        for _ in 0..<4 { h.answerCorrectly() }
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(500))
        #expect(h.state.streak == 5)
        #expect(h.contains(.streakMilestone(streak: 5), in: produced))
        #expect(!h.contains(.correct(streak: 5), in: produced))
        // 100 x 2 + 50 x (1.5 / 2.0) = 237.5, rounded to 238
        guard case .itemResolved(let result, _) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.points == 238)
    }

    @Test func windowTrimsAfterFiveStreak() {
        var h = RunHarness()
        h.startRunAndRound()
        for _ in 0..<5 { h.answerCorrectly() }
        #expect(h.activeItem?.window == .milliseconds(1950))
        h.answerWrong()
        #expect(h.activeItem?.window == .seconds(2))
    }

    @Test func fullRunEndsAfterEightRounds() {
        var h = RunHarness()
        h.send(.startRun)
        for round in 0..<8 {
            #expect(h.state.phase == .roundIntro(h.state.plans[round]))
            h.send(.startRound)
            h.answerCorrectly()
            h.finishRoundByClock()
        }
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .completedAllRounds)
        #expect(summary.rounds.count == 8)
        #expect(summary.roundsCompleted == 8)
        #expect(summary.score == h.state.score)
        #expect(summary.score == summary.rounds.reduce(0) { $0 + $1.score })
    }

    @Test func itemStreamDoesNotDependOnEarlierRoundPace() {
        var fast = RunHarness(seed: 5)
        var slow = RunHarness(seed: 5)
        fast.startRunAndRound()
        slow.startRunAndRound()
        for _ in 0..<3 { fast.answerCorrectly(reaction: .milliseconds(200)) }
        for _ in 0..<12 { slow.answerCorrectly(reaction: .milliseconds(200)) }
        fast.finishRoundByClock()
        slow.finishRoundByClock()
        fast.send(.startRound)
        slow.send(.startRound)
        #expect(fast.activeItem?.item == slow.activeItem?.item)
        for _ in 0..<5 {
            fast.answerCorrectly()
            slow.answerCorrectly()
            #expect(fast.activeItem?.item == slow.activeItem?.item)
        }
    }
}
