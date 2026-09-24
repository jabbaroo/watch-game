import Testing
@testable import SwipeSortEngine

@Suite struct RunStatePauseTests {
    @Test func pauseFreezesRoundClockAndResumeShiftsDeadline() throws {
        var h = RunHarness()
        h.startRunAndRound()
        let before = h.activeItem!
        h.send(.pause, after: .milliseconds(500))
        #expect(h.state.roundTimeRemaining(at: h.now) == .milliseconds(39_500))
        #expect(h.state.roundTimeRemaining(at: h.now + .seconds(30)) == .milliseconds(39_500))
        let produced = h.send(.resume, after: .seconds(10))
        let after = try #require(h.activeItem)
        #expect(after.index == before.index)
        #expect(after.item == before.item)
        #expect(after.deadline == before.deadline + .seconds(10))
        #expect(after.shownAt == before.shownAt + .seconds(10))
        #expect(h.state.roundTimeRemaining(at: h.now) == .milliseconds(39_500))
        #expect(produced.contains(.itemShown(after)))
        #expect(produced.contains(.wake(at: after.deadline)))
    }

    @Test func reactionTimeExcludesPausedTime() {
        var h = RunHarness()
        h.startRunAndRound()
        h.send(.pause, after: .milliseconds(200))
        h.send(.resume, after: .seconds(5))
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(300))
        guard case .itemResolved(let result, _) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.reaction == .milliseconds(500))
    }

    @Test func pauseDuringGapShiftsNextItemTime() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        h.send(.answer(active.expectedEdge), after: .milliseconds(400))
        #expect(h.state.phase == .betweenItems(nextItemAt: .milliseconds(650)))
        h.send(.pause, after: .milliseconds(100))
        let produced = h.send(.resume, after: .seconds(2))
        #expect(h.state.phase == .betweenItems(nextItemAt: .milliseconds(2650)))
        #expect(produced == [.wake(at: .milliseconds(2650))])
        h.send(.tick, after: .milliseconds(150))
        #expect(h.activeItem?.index == 1)
    }

    @Test func eventsWhilePausedAreIgnored() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        h.send(.pause, after: .milliseconds(100))
        #expect(h.send(.answer(active.expectedEdge), after: .milliseconds(100)).isEmpty)
        #expect(h.send(.tick, after: .seconds(50)).isEmpty)
        #expect(h.send(.pause).isEmpty)
        if case .paused = h.state.phase {} else { Issue.record("should still be paused") }
        #expect(h.state.lives == 3)
    }

    @Test func pauseIsIgnoredOutsideActivePlay() {
        var h = RunHarness()
        h.send(.startRun)
        #expect(h.send(.pause).isEmpty)
        #expect(h.state.phase == .roundIntro(h.state.plans[0]))
        #expect(h.send(.resume).isEmpty)
    }

    @Test func quitKeepsFinishedRoundsAndMarksIncomplete() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        h.finishRoundByClock()
        h.send(.startRound)
        h.answerCorrectly()
        h.answerWrong()
        let produced = h.send(.quit)
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .quit)
        #expect(!summary.completed)
        #expect(summary.rounds.count == 1)
        #expect(summary.rounds[0].index == 0)
        #expect(summary.livesRemaining == 2)
        #expect(produced.contains(.runEnded(summary)))
        #expect(!h.contains(.runEnded, in: produced), "quit is silent: no run-end haptic or sting")
        #expect(h.send(.tick, after: .seconds(1)).isEmpty)
    }

    @Test func quitWhilePausedWorks() {
        var h = RunHarness()
        h.startRunAndRound()
        h.send(.pause, after: .milliseconds(100))
        h.send(.quit)
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .quit)
        #expect(summary.rounds.isEmpty)
    }
}
