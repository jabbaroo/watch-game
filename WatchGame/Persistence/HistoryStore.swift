import Foundation
import OSLog
import SwiftData
import SwipeSortEngine

/// The only object that talks to SwiftData. Main-actor bound like the views that read it.
@MainActor
final class HistoryStore {
    static let schema = Schema([RunEntry.self, RoundEntry.self, ItemEntry.self])
    private static let logger = Logger(subsystem: "com.pynto.sortsprint", category: "history")

    /// Retained on purpose: a ModelContext does not keep its container alive.
    let container: ModelContainer
    let context: ModelContext
    /// True when the persistent store failed and an in-memory store is being used instead.
    private(set) var isFallback = false

    init(container: ModelContainer, isFallback: Bool = false) {
        self.container = container
        context = container.mainContext
        context.autosaveEnabled = true
        self.isFallback = isFallback
    }

    /// Opens the on-disk store, or an in-memory one if that fails.
    static func open() -> HistoryStore {
        do {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            return HistoryStore(container: container)
        } catch {
            logger.error("Persistent store unavailable, using in-memory history: \(String(describing: error), privacy: .public)")
            let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            return HistoryStore(container: container, isFallback: true)
        }
    }

    // MARK: - Writing

    @discardableResult
    func beginRun(packID: String, isDaily: Bool, dailyKey: String?, seed: UInt64, startedAt: Date = .now) -> RunEntry {
        let run = RunEntry(startedAt: startedAt, packID: packID, isDaily: isDaily, dailyKey: dailyKey, seed: seed)
        context.insert(run)
        save()
        return run
    }

    func append(_ result: RoundResult, to run: RunEntry) {
        let entry = RoundEntry(result: result)
        context.insert(entry)
        entry.run = run
        save()
    }

    func finish(_ run: RunEntry, summary: RunSummary, endedAt: Date = .now) {
        run.endedAt = endedAt
        run.score = summary.score
        run.roundsCompleted = summary.roundsCompleted
        run.livesRemaining = summary.livesRemaining
        run.completed = summary.completed
        run.endReason = summary.endReason
        save()
    }

    /// Runs with no end time were interrupted by a process kill. Call once at launch.
    func markAbandonedRuns(at date: Date = .now) {
        let open = fetch(FetchDescriptor<RunEntry>(predicate: #Predicate { $0.endedAt == nil }))
        for run in open {
            run.endedAt = date
            run.completed = false
            run.endReason = .abandoned
            run.roundsCompleted = run.roundResults.filter { !$0.cutShort }.count
            run.score = run.roundResults.reduce(0) { $0 + $1.score }
        }
        save()
    }

    func reset() {
        for run in allRuns() {
            context.delete(run)
        }
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Save failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Reading

    func allRuns(limit: Int? = nil) -> [RunEntry] {
        var descriptor = FetchDescriptor<RunEntry>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    func completedRuns(limit: Int? = nil) -> [RunEntry] {
        var descriptor = FetchDescriptor<RunEntry>(
            predicate: #Predicate { $0.completed == true },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    func bestScore() -> Int? {
        completedRuns().map(\.score).max()
    }

    func hasCompletedDaily(dayKey: String) -> Bool {
        !fetch(FetchDescriptor<RunEntry>(predicate: #Predicate { $0.completed == true && $0.isDaily == true && $0.dailyKey == dayKey })).isEmpty
    }

    /// Consecutive days with a completed daily ending today, or ending yesterday if today is unplayed.
    func dailyStreak(today: Date = .now, calendar: Calendar = .current) -> Int {
        let played = Set(fetch(FetchDescriptor<RunEntry>(predicate: #Predicate { $0.completed == true && $0.isDaily == true })).compactMap(\.dailyKey))
        guard !played.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: today)
        if !played.contains(DailySeed.dayKey(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while played.contains(DailySeed.dayKey(for: day, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Fetch failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
