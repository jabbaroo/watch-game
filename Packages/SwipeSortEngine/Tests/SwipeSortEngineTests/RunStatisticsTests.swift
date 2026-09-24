import Testing
@testable import SwipeSortEngine

@Suite struct RunStatisticsTests {
    func item(_ index: Int, round: Int = 0, dimension: String = "colour", expected: String = "red",
              answered: String? = "red", correct: Bool = true, timedOut: Bool = false,
              reaction: Duration? = .milliseconds(500)) -> ItemResult {
        ItemResult(roundIndex: round, itemIndex: index, dimensionID: dimension, attributes: [:],
                   expectedCategoryID: expected, answeredCategoryID: answered, correct: correct,
                   timedOut: timedOut, reaction: reaction, window: .seconds(2), points: correct ? 100 : 0)
    }

    func round(_ index: Int, dimension: String = "colour", items: [ItemResult]) -> RoundResult {
        RoundResult(index: index, dimensionID: dimension, categoryCount: 2, perfect: false, cutShort: false, score: 0, items: items)
    }

    @Test func countsAndAccuracy() {
        let rounds = [round(0, items: [
            item(0),
            item(1, expected: "red", answered: "blue", correct: false),
            item(2, answered: nil, correct: false, timedOut: true, reaction: nil),
            item(3),
        ])]
        let stats = RunStatistics.compute(rounds: rounds)
        #expect(stats.resolvedCount == 4)
        #expect(stats.correctCount == 2)
        #expect(stats.wrongSwipeCount == 1)
        #expect(stats.timeoutCount == 1)
        #expect(stats.accuracy == 0.5)
    }

    @Test func emptyRunHasNilRatios() {
        let stats = RunStatistics.compute(rounds: [])
        #expect(stats.accuracy == nil)
        #expect(stats.meanReaction == nil)
        #expect(stats.switchCost == nil)
        #expect(stats.confusionPairs.isEmpty)
        #expect(stats.errorsByDimension.isEmpty)
    }

    @Test func errorsByDimensionInFirstSeenOrder() {
        let rounds = [
            round(0, dimension: "shape", items: [item(0, dimension: "shape"), item(1, dimension: "shape", answered: "x", correct: false)]),
            round(1, dimension: "colour", items: [item(0), item(1), item(2, answered: "blue", correct: false), item(3, answered: nil, correct: false, timedOut: true, reaction: nil)]),
        ]
        let stats = RunStatistics.compute(rounds: rounds)
        #expect(stats.errorsByDimension == [
            DimensionErrorRate(dimensionID: "shape", errors: 1, total: 2),
            DimensionErrorRate(dimensionID: "colour", errors: 2, total: 4),
        ])
        #expect(stats.errorsByDimension[1].rate == 0.5)
    }

    @Test func confusionPairsSortedByCountThenIDs() {
        let rounds = [round(0, items: [
            item(0, expected: "red", answered: "blue", correct: false),
            item(1, expected: "red", answered: "blue", correct: false),
            item(2, expected: "green", answered: "yellow", correct: false),
            item(3, expected: "blue", answered: "red", correct: false),
            item(4, expected: "red", answered: nil, correct: false, timedOut: true, reaction: nil),
        ])]
        let stats = RunStatistics.compute(rounds: rounds)
        #expect(stats.confusionPairs == [
            ConfusionPair(expectedCategoryID: "red", answeredCategoryID: "blue", count: 2),
            ConfusionPair(expectedCategoryID: "blue", answeredCategoryID: "red", count: 1),
            ConfusionPair(expectedCategoryID: "green", answeredCategoryID: "yellow", count: 1),
        ])
    }

    @Test func meanReactionUsesCorrectItemsOnly() {
        let rounds = [round(0, items: [
            item(0, reaction: .milliseconds(400)),
            item(1, reaction: .milliseconds(600)),
            item(2, answered: "blue", correct: false, reaction: .milliseconds(5000)),
        ])]
        #expect(RunStatistics.compute(rounds: rounds).meanReaction == .milliseconds(500))
    }

    @Test func switchCostIsLeadingMinusRest() {
        // First three correct items average 900 ms, the rest average 500 ms: cost 400 ms.
        let roundA = round(0, items: [
            item(0, reaction: .milliseconds(1000)),
            item(1, answered: "blue", correct: false, reaction: .milliseconds(100)),
            item(2, reaction: .milliseconds(900)),
            item(3, reaction: .milliseconds(800)),
            item(4, reaction: .milliseconds(500)),
            item(5, reaction: .milliseconds(500)),
            item(6, reaction: .milliseconds(500)),
        ])
        // Only five correct items: does not qualify.
        let roundB = round(1, items: (0..<5).map { item($0, reaction: .milliseconds(300)) })
        let stats = RunStatistics.compute(rounds: [roundA, roundB])
        #expect(stats.switchCost == .milliseconds(400))
    }

    @Test func switchCostAveragesAcrossQualifyingRounds() {
        let roundA = round(0, items: [800, 800, 800, 400, 400, 400].enumerated().map { item($0.offset, reaction: .milliseconds($0.element)) })
        let roundB = round(1, items: [600, 600, 600, 400, 400, 400].enumerated().map { item($0.offset, reaction: .milliseconds($0.element)) })
        #expect(RunStatistics.compute(rounds: [roundA, roundB]).switchCost == .milliseconds(300))
    }
}
