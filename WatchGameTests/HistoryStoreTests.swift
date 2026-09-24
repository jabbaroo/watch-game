import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite struct HistoryStoreTests {
    func makeStore() throws -> HistoryStore {
        let container = try ModelContainer(
            for: RunEntry.self, RoundEntry.self, ItemEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return HistoryStore(container: container)
    }

    func item(_ index: Int, correct: Bool = true) -> ItemResult {
        ItemResult(roundIndex: 0, itemIndex: index, dimensionID: "colour", attributes: ["colour": "red", "shape": "star"],
                   expectedCategoryID: "red", answeredCategoryID: correct ? "red" : "blue", correct: correct, timedOut: false,
                   reaction: .milliseconds(450), window: .seconds(2), points: correct ? 100 : 0)
    }

    func round(_ index: Int, score: Int = 200, cutShort: Bool = false) -> RoundResult {
        RoundResult(index: index, dimensionID: "colour", categoryCount: 2, perfect: false, cutShort: cutShort, score: score, items: [item(0), item(1, correct: false)])
    }

    func summary(score: Int, rounds: [RoundResult], reason: RunEndReason = .completedAllRounds) -> RunSummary {
        RunSummary(seed: 7, packID: "shapes-colours", score: score, livesRemaining: 1, endReason: reason, rounds: rounds)
    }

    @Test func runRoundTripsToResults() throws {
        let store = try makeStore()
        let run = store.beginRun(packID: "shapes-colours", isDaily: false, dailyKey: nil, seed: 7)
        store.append(round(0), to: run)
        store.append(round(1, score: 300), to: run)
        store.finish(run, summary: summary(score: 500, rounds: [round(0), round(1, score: 300)]))
        let results = run.roundResults
        #expect(results == [round(0), round(1, score: 300)])
        #expect(run.score == 500)
        #expect(run.completed)
        #expect(run.roundsCompleted == 2)
        #expect(run.endedAt != nil)
        #expect(UInt64(bitPattern: run.seed) == 7)
    }

    @Test func abandonedRunsAreMarkedIncomplete() throws {
        let store = try makeStore()
        let run = store.beginRun(packID: "shapes-colours", isDaily: false, dailyKey: nil, seed: 1)
        store.append(round(0), to: run)
        store.save()
        store.markAbandonedRuns()
        #expect(run.endedAt != nil)
        #expect(!run.completed)
        #expect(run.endReason == .abandoned)
        #expect(store.completedRuns().isEmpty)
        #expect(store.allRuns().count == 1)
    }

    @Test func bestScoreUsesCompletedRunsOnly() throws {
        let store = try makeStore()
        let good = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 1)
        store.finish(good, summary: summary(score: 900, rounds: []))
        let quit = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 2)
        store.finish(quit, summary: summary(score: 5000, rounds: [], reason: .quit))
        #expect(store.bestScore() == 900)
    }

    @Test func dailyStreakCountsConsecutiveDays() throws {
        let store = try makeStore()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_790_208_000)) // 2026-09-24 UTC
        func play(daysAgo: Int, completed: Bool = true) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let key = DailySeed.dayKey(for: date, calendar: calendar)
            let run = store.beginRun(packID: "p", isDaily: true, dailyKey: key, seed: 1, startedAt: date)
            store.finish(run, summary: summary(score: 100, rounds: [], reason: completed ? .completedAllRounds : .quit), endedAt: date)
        }
        #expect(store.dailyStreak(today: today, calendar: calendar) == 0)
        play(daysAgo: 1)
        play(daysAgo: 2)
        play(daysAgo: 3)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 3, "yesterday counts when today is unplayed")
        play(daysAgo: 0)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 4)
        play(daysAgo: 5)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 4, "a gap breaks the streak")
        play(daysAgo: 4, completed: false)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 4, "quit runs do not count")
        #expect(store.hasCompletedDaily(dayKey: DailySeed.dayKey(for: today, calendar: calendar)))
    }

    @Test func resetRemovesEverything() throws {
        let store = try makeStore()
        let run = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 1)
        store.append(round(0), to: run)
        store.finish(run, summary: summary(score: 100, rounds: [round(0)]))
        store.reset()
        #expect(store.allRuns().isEmpty)
        #expect(store.bestScore() == nil)
    }
}
