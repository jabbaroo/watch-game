import Foundation
import SwipeSortEngine

/// Everything the History screen shows, computed from completed runs only.
struct HistorySummary {
    struct Point: Identifiable, Equatable {
        let id: UUID
        /// 1-based position among the plotted runs, oldest first.
        let index: Int
        let date: Date
        let score: Int
        let reactionSeconds: Double?
        let switchCostMilliseconds: Double?
    }

    enum TimeOfDay: String, CaseIterable {
        case morning, afternoon, evening, night

        static func bucket(hour: Int) -> TimeOfDay {
            switch hour {
            case 5...11: .morning
            case 12...16: .afternoon
            case 17...21: .evening
            default: .night
            }
        }

        var title: String {
            switch self {
            case .morning: String(localized: "Morning")
            case .afternoon: String(localized: "Afternoon")
            case .evening: String(localized: "Evening")
            case .night: String(localized: "Night")
            }
        }
    }

    var bestScore: Int?
    var runsPlayed: Int
    var dailyStreak: Int
    var points: [Point]
    var sharpestTimeOfDay: TimeOfDay?
    var recentRuns: [RunEntry]

    static let chartLimit = 30
    static let minimumRunsPerBucket = 3

    @MainActor
    static func make(store: HistoryStore, calendar: Calendar = .current, now: Date = .now) -> HistorySummary {
        let completed = store.completedRuns()
        let plotted = Array(completed.prefix(chartLimit)).reversed()
        let points = plotted.enumerated().map { offset, run -> Point in
            let statistics = RunStatistics.compute(rounds: run.roundResults)
            return Point(
                id: run.id,
                index: offset + 1,
                date: run.startedAt,
                score: run.score,
                reactionSeconds: statistics.meanReaction?.seconds,
                switchCostMilliseconds: statistics.switchCost.map { $0 / .milliseconds(1) }
            )
        }

        var reactionsByBucket: [TimeOfDay: [Double]] = [:]
        for run in completed {
            guard let reaction = RunStatistics.compute(rounds: run.roundResults).meanReaction?.seconds else { continue }
            let hour = calendar.component(.hour, from: run.startedAt)
            reactionsByBucket[TimeOfDay.bucket(hour: hour), default: []].append(reaction)
        }
        let sharpest = reactionsByBucket
            .filter { $0.value.count >= minimumRunsPerBucket }
            .map { (bucket: $0.key, mean: $0.value.reduce(0, +) / Double($0.value.count)) }
            .min { $0.mean < $1.mean }?
            .bucket

        return HistorySummary(
            bestScore: completed.map(\.score).max(),
            runsPlayed: completed.count,
            dailyStreak: store.dailyStreak(today: now, calendar: calendar),
            points: points,
            sharpestTimeOfDay: sharpest,
            recentRuns: store.allRuns(limit: chartLimit)
        )
    }
}
