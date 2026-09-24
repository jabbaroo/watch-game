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

    /// One headline number per cognitive dimension, with the latest and the best value across completed runs.
    struct ProfileMetric: Identifiable, Equatable {
        enum Kind: String, CaseIterable {
            case speed, switching, interference, control, memory

            var title: String {
                switch self {
                case .speed: String(localized: "Speed")
                case .switching: String(localized: "Switching")
                case .interference: String(localized: "Interference")
                case .control: String(localized: "Control")
                case .memory: String(localized: "Memory")
                }
            }

            /// Lower is better for everything except memory accuracy.
            var higherIsBetter: Bool { self == .memory }

            /// The raw value a run contributes, or nil when the run did not measure this dimension.
            func value(from statistics: RunStatistics) -> Double? {
                switch self {
                case .speed: statistics.meanReaction?.seconds
                case .switching: statistics.switchCost.map { $0 / .milliseconds(1) }
                case .interference: statistics.conflictCost.map { $0 / .milliseconds(1) }
                case .control: statistics.falseAlarmRate
                case .memory: statistics.accuracyByDepth[2]
                }
            }

            func format(_ value: Double) -> String {
                switch self {
                case .speed: String(format: "%.2f s", value)
                case .switching, .interference: String(format: "%+d ms", Int(value.rounded()))
                case .control: String(localized: "\(Int((value * 100).rounded()))% false alarms")
                case .memory: String(localized: "\(Int((value * 100).rounded()))% at 2-back")
                }
            }
        }

        let kind: Kind
        let latest: Double
        let best: Double
        var id: Kind { kind }
    }

    var bestScore: Int?
    var runsPlayed: Int
    var dailyStreak: Int
    var points: [Point]
    var sharpestTimeOfDay: TimeOfDay?
    var profile: [ProfileMetric]
    var recentRuns: [RunEntry]

    static let chartLimit = 30
    static let minimumRunsPerBucket = 3

    @MainActor
    static func make(store: HistoryStore, calendar: Calendar = .current, now: Date = .now) -> HistorySummary {
        let completed = store.completedRuns()
        let statisticsByRun = Dictionary(uniqueKeysWithValues: completed.map { ($0.id, RunStatistics.compute(rounds: $0.roundResults)) })
        let plotted = Array(completed.prefix(chartLimit)).reversed()
        let points = plotted.enumerated().map { offset, run -> Point in
            let statistics = statisticsByRun[run.id] ?? RunStatistics.compute(rounds: [])
            return Point(
                id: run.id,
                index: offset + 1,
                date: run.startedAt,
                score: run.score,
                reactionSeconds: statistics.meanReaction?.seconds,
                switchCostMilliseconds: statistics.switchCost.map { $0 / .milliseconds(1) }
            )
        }

        // Profile: newest run first, so the first value seen per kind is the latest.
        var profile: [ProfileMetric] = []
        for kind in ProfileMetric.Kind.allCases {
            let values = completed.compactMap { statisticsByRun[$0.id].flatMap(kind.value(from:)) }
            guard let latest = values.first, let best = kind.higherIsBetter ? values.max() : values.min() else { continue }
            profile.append(ProfileMetric(kind: kind, latest: latest, best: best))
        }

        var reactionsByBucket: [TimeOfDay: [Double]] = [:]
        for run in completed {
            guard let reaction = statisticsByRun[run.id]?.meanReaction?.seconds else { continue }
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
            profile: profile,
            recentRuns: store.allRuns(limit: chartLimit)
        )
    }
}
