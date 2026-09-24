import Testing
@testable import SwipeSortEngine

/// N-back: primers just show, then every item is judged against the one shown `depth` steps earlier.
@Suite struct RunStateBackTests {
    static var twoBack: ContentPack {
        var pack = ContentPack.shapesAndColours
        pack.backRamp = [1, 1, 2]
        return pack
    }

    @Test func packBackDepthRampReusesTheLastValue() {
        let pack = Self.twoBack
        #expect((0..<5).map(pack.backDepth(roundIndex:)) == [1, 1, 2, 2, 2])
        #expect(ContentPack.shapesAndColours.backDepth(roundIndex: 3) == 0)
        var bad = pack
        bad.backRamp = [4]
        #expect(throws: ContentPack.ValidationError.invalidBackDepth(4)) { try bad.validate() }
    }

    @Test func plansCarryTheDepth() {
        let h = RunHarness(pack: Self.twoBack)
        #expect(h.state.plans.map(\.backDepth) == [1, 1, 2, 2, 2, 2, 2, 2])
    }

    @Test func primersIgnoreInputAndFinishNeutrally() {
        var h = RunHarness(pack: Self.twoBack)
        h.startRunAndRound()
        let primer = h.activeItem!
        #expect(primer.isPrimer)
        #expect(primer.index == 0)
        #expect(primer.window == .seconds(2), "primers get no first-item grace")
        let ignored = h.send(.answer(primer.expectedEdge), after: .milliseconds(300))
        #expect(ignored == [.wake(at: primer.deadline)])
        #expect(h.state.lives == 3)
        #expect(h.state.score == 0)
        let finished = h.send(.tick, after: primer.deadline - h.now)
        guard case .itemResolved(let result, let outcome) = finished[0] else {
            Issue.record("primer should resolve"); return
        }
        #expect(outcome == .primed)
        #expect(result.points == 0)
        #expect(h.state.currentRoundItems.isEmpty, "primers are not recorded")
        #expect(h.state.lives == 3)
        #expect(h.state.streak == 0)
    }

    @Test func firstAnswerableItemIsJudgedAgainstThePreviousOneAndGetsGrace() {
        var h = RunHarness(pack: Self.twoBack)
        h.startRunAndRound()
        let primer = h.activeItem!
        h.send(.tick, after: primer.window)
        h.advanceToNextItem()
        let first = h.activeItem!
        #expect(!first.isPrimer)
        #expect(first.index == 1)
        #expect(first.expectedCategoryID == primer.item.attributes["colour"], "one-back: sort the previous item's colour")
        #expect(first.window == .seconds(3), "the first answerable item carries the grace")
        let produced = h.send(.answer(first.expectedEdge), after: .milliseconds(500))
        #expect(h.state.streak == 1)
        #expect(h.state.score > 0)
        guard case .itemResolved(let result, _) = produced[0] else { Issue.record("should resolve"); return }
        #expect(result.correct)
        #expect(result.expectedCategoryID == primer.item.attributes["colour"])
        #expect(result.attributes == first.item.attributes, "the record describes the item on screen")
    }

    @Test func twoBackUsesTheItemTwoStepsEarlier() {
        var h = RunHarness(pack: Self.twoBack)
        h.send(.startRun)
        for _ in 0..<2 {
            h.send(.startRound)
            h.finishRoundByClock()
        }
        #expect(h.state.currentPlan.backDepth == 2)
        h.send(.startRound)
        var shown: [String] = []
        for expectedIndex in 0..<2 {
            let primer = h.activeItem!
            #expect(primer.isPrimer)
            #expect(primer.index == expectedIndex)
            shown.append(primer.item.attributes["colour"]!)
            h.send(.tick, after: primer.window)
            h.advanceToNextItem()
        }
        for step in 0..<6 {
            let active = h.activeItem!
            #expect(!active.isPrimer)
            #expect(active.expectedCategoryID == shown[step], "item \(active.index) is judged against item \(step)")
            shown.append(active.item.attributes["colour"]!)
            h.send(.answer(active.expectedEdge), after: .milliseconds(400))
            h.advanceToNextItem()
        }
        #expect(h.state.streak == 6)
        #expect(h.state.lives == 3)
    }

    @Test func accuracyByDepthComesFromRoundDepths() {
        var h = RunHarness(pack: Self.twoBack)
        h.startRunAndRound()
        let primer = h.activeItem!
        h.send(.tick, after: primer.window)
        h.advanceToNextItem()
        for _ in 0..<3 {
            let active = h.activeItem!
            h.send(.answer(active.expectedEdge), after: .milliseconds(400))
            h.advanceToNextItem()
        }
        let wrong = h.activeItem!
        let wrongEdge = h.state.currentPlan.mapping.edges.first { $0 != wrong.expectedEdge }!
        h.send(.answer(wrongEdge), after: .milliseconds(400))
        h.finishRoundByClock()
        let stats = RunStatistics.compute(rounds: h.state.completedRounds)
        #expect(stats.accuracyByDepth == [1: 0.75])
        #expect(stats.resolvedCount == 4, "the primer is not counted")
        #expect(h.state.completedRounds[0].backDepth == 1)
    }

    @Test func plainPacksHaveNoPrimersAndNoDepthAccuracy() {
        var h = RunHarness()
        h.startRunAndRound()
        #expect(h.activeItem?.isPrimer == false)
        h.answerCorrectly()
        h.finishRoundByClock()
        #expect(RunStatistics.compute(rounds: h.state.completedRounds).accuracyByDepth.isEmpty)
    }
}
