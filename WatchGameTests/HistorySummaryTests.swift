import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite struct HistorySummaryTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func makeStore() throws -> HistoryStore {
        let container = try ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        return HistoryStore(container: container)
    }

    func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func round(reactionMilliseconds: Int) -> RoundResult {
        let items = (0..<6).map { index in
            ItemResult(roundIndex: 0, itemIndex: index, dimensionID: "colour", attributes: [:], expectedCategoryID: "red",
                       answeredCategoryID: "red", correct: true, timedOut: false,
                       reaction: .milliseconds(reactionMilliseconds), window: .seconds(2), points: 100)
        }
        return RoundResult(index: 0, dimensionID: "colour", categoryCount: 2, perfect: true, cutShort: false, score: 600, items: items)
    }

    @discardableResult
    func play(_ store: HistoryStore, day: Int, hour: Int, score: Int, reactionMilliseconds: Int, completed: Bool = true) -> RunEntry {
        let started = date(day: day, hour: hour)
        let run = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 1, startedAt: started)
        let round = round(reactionMilliseconds: reactionMilliseconds)
        store.append(round, to: run)
        store.finish(run, summary: RunSummary(seed: 1, packID: "p", score: score, livesRemaining: 3,
                                              endReason: completed ? .completedAllRounds : .quit, rounds: [round]),
                     endedAt: started.addingTimeInterval(400))
        return run
    }

    @Test func timeOfDayBuckets() {
        #expect(HistorySummary.TimeOfDay.bucket(hour: 5) == .morning)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 11) == .morning)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 12) == .afternoon)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 16) == .afternoon)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 17) == .evening)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 21) == .evening)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 22) == .night)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 4) == .night)
    }

    @Test func tilesAndPointsUseCompletedRunsOldestFirst() throws {
        let store = try makeStore()
        play(store, day: 1, hour: 9, score: 500, reactionMilliseconds: 600)
        play(store, day: 2, hour: 9, score: 900, reactionMilliseconds: 500)
        play(store, day: 3, hour: 9, score: 5000, reactionMilliseconds: 100, completed: false)
        let summary = HistorySummary.make(store: store, calendar: calendar)
        #expect(summary.bestScore == 900)
        #expect(summary.runsPlayed == 2)
        #expect(summary.points.map(\.score) == [500, 900])
        #expect(summary.points.map(\.reactionSeconds) == [0.6, 0.5])
        #expect(summary.points.first?.index == 1)
    }

    @Test func sharpestTimeNeedsThreeRunsPerBucket() throws {
        let store = try makeStore()
        play(store, day: 1, hour: 8, score: 1, reactionMilliseconds: 400)
        play(store, day: 2, hour: 8, score: 1, reactionMilliseconds: 400)
        play(store, day: 3, hour: 20, score: 1, reactionMilliseconds: 300)
        play(store, day: 4, hour: 20, score: 1, reactionMilliseconds: 300)
        #expect(HistorySummary.make(store: store, calendar: calendar).sharpestTimeOfDay == nil)
        play(store, day: 5, hour: 8, score: 1, reactionMilliseconds: 400)
        #expect(HistorySummary.make(store: store, calendar: calendar).sharpestTimeOfDay == .morning)
        play(store, day: 6, hour: 20, score: 1, reactionMilliseconds: 300)
        #expect(HistorySummary.make(store: store, calendar: calendar).sharpestTimeOfDay == .evening)
    }

    @Test func pointsAreLimitedToThirtyMostRecent() throws {
        let store = try makeStore()
        for day in 1...35 {
            play(store, day: min(day, 30), hour: day % 24, score: day, reactionMilliseconds: 500)
        }
        let summary = HistorySummary.make(store: store, calendar: calendar)
        #expect(summary.points.count == 30)
        #expect(summary.runsPlayed == 35)
    }
}
