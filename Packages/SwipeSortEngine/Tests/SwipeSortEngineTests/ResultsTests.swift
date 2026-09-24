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

    @Test func roundResultDecodesWithoutTheBackDepthKey() throws {
        let legacy = """
        {"index":0,"dimensionID":"colour","categoryCount":2,"perfect":false,"cutShort":false,"score":0,"items":[]}
        """
        let round = try JSONDecoder().decode(RoundResult.self, from: Data(legacy.utf8))
        #expect(round.backDepth == 0)
        var deep = round
        deep.backDepth = 2
        #expect(try JSONDecoder().decode(RoundResult.self, from: JSONEncoder().encode(deep)).backDepth == 2)
    }

    @Test func itemResultDecodesWithoutTheHoldKey() throws {
        let legacy = """
        {"roundIndex":0,"itemIndex":1,"dimensionID":"colour","attributes":{"colour":"red"},"expectedCategoryID":"red",
         "answeredCategoryID":"red","correct":true,"timedOut":false,"reaction":[0,500000000000000000],"window":[2,0],"points":100}
        """
        let item = try JSONDecoder().decode(ItemResult.self, from: Data(legacy.utf8))
        #expect(item.hold == false)
        #expect(item.reaction == .milliseconds(500))
        var held = item
        held.hold = true
        #expect(try JSONDecoder().decode(ItemResult.self, from: JSONEncoder().encode(held)).hold)
    }
}
