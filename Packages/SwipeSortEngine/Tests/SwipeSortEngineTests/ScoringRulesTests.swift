import Testing
@testable import SwipeSortEngine

@Suite struct ScoringRulesTests {
    let rules = ScoringRules()

    @Test func multiplierTable() {
        let expected: [(Int, Int)] = [(1, 1), (4, 1), (5, 2), (9, 2), (10, 3), (14, 3), (15, 4), (100, 4)]
        for (streak, multiplier) in expected {
            #expect(rules.multiplier(streak: streak) == multiplier, "streak \(streak)")
        }
    }

    @Test func speedBonusScalesWithRemainingWindow() {
        #expect(rules.speedBonus(reaction: .zero, window: .seconds(2)) == 50)
        #expect(rules.speedBonus(reaction: .seconds(1), window: .seconds(2)) == 25)
        #expect(rules.speedBonus(reaction: .seconds(2), window: .seconds(2)) == 0)
        #expect(rules.speedBonus(reaction: .seconds(3), window: .seconds(2)) == 0)
    }

    @Test func pointsCombineBaseMultiplierAndBonus() {
        #expect(rules.points(streak: 1, reaction: .seconds(1), window: .seconds(2)) == 125)
        #expect(rules.points(streak: 6, reaction: .seconds(1), window: .seconds(2)) == 225)
        #expect(rules.points(streak: 16, reaction: .zero, window: .seconds(2)) == 450)
    }

    @Test func perfectRoundBonusIsFiveHundred() {
        #expect(rules.perfectRoundBonus == 500)
    }
}
