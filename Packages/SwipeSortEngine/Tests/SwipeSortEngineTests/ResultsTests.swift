import Foundation
import Testing
@testable import SwipeSortEngine

@Suite struct ResultsTests {
    func round(index: Int, cutShort: Bool) -> RoundResult {
        RoundResult(index: index, dimensionID: "colour", categoryCount: 2, perfect: false, cutShort: cutShort, score: 0, items: [])
    }

    @Test func roundsCompletedIgnoresCutShortRounds() {
        let summary = RunSummary(seed: 1, packID: "p", score: 0, livesRemaining: 0, endReason: .outOfLives,
                                 rounds: [round(index: 0, cutShort: false), round(index: 1, cutShort: true)])
        #expect(summary.roundsCompleted == 1)
    }

    @Test func completedOnlyForNaturalEndings() {
        for reason in [RunEndReason.completedAllRounds, .outOfLives] {
            let summary = RunSummary(seed: 1, packID: "p", score: 0, livesRemaining: 0, endReason: reason, rounds: [])
            #expect(summary.completed)
        }
        for reason in [RunEndReason.quit, .abandoned] {
            let summary = RunSummary(seed: 1, packID: "p", score: 0, livesRemaining: 0, endReason: reason, rounds: [])
            #expect(!summary.completed)
        }
    }

    @Test func resultsRoundTripThroughJSON() throws {
        let item = ItemResult(roundIndex: 0, itemIndex: 3, dimensionID: "colour", attributes: ["colour": "red", "shape": "star"],
                              expectedCategoryID: "red", answeredCategoryID: "blue", correct: false, timedOut: false,
                              reaction: .milliseconds(420), window: .seconds(2), points: 0)
        let round = RoundResult(index: 0, dimensionID: "colour", categoryCount: 2, perfect: false, cutShort: false, score: 0, items: [item])
        let summary = RunSummary(seed: 99, packID: "p", score: 0, livesRemaining: 2, endReason: .completedAllRounds, rounds: [round])
        let data = try JSONEncoder().encode(summary)
        #expect(try JSONDecoder().decode(RunSummary.self, from: data) == summary)
    }
}
