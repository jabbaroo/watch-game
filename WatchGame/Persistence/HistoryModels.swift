import Foundation
import SwiftData
import SwipeSortEngine

// Every property has a default and every relationship is optional so the schema
// stays CloudKit-compatible if sync is enabled later.

@Model
final class RunEntry {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var packID: String = ""
    var isDaily: Bool = false
    var dailyKey: String?
    /// `UInt64` bit pattern; SwiftData stores signed integers.
    var seed: Int64 = 0
    var score: Int = 0
    var roundsCompleted: Int = 0
    var livesRemaining: Int = 0
    var completed: Bool = false
    var endReasonRaw: String = RunEndReason.quit.rawValue
    @Relationship(deleteRule: .cascade, inverse: \RoundEntry.run)
    var rounds: [RoundEntry]? = []

    init(startedAt: Date, packID: String, isDaily: Bool, dailyKey: String?, seed: UInt64) {
        self.startedAt = startedAt
        self.packID = packID
        self.isDaily = isDaily
        self.dailyKey = dailyKey
        self.seed = Int64(bitPattern: seed)
    }

    var endReason: RunEndReason {
        get { RunEndReason(rawValue: endReasonRaw) ?? .quit }
        set { endReasonRaw = newValue.rawValue }
    }

    /// Rounds as engine values, in index order, for `RunStatistics`.
    var roundResults: [RoundResult] {
        (rounds ?? []).sorted { $0.index < $1.index }.map(\.result)
    }
}

@Model
final class RoundEntry {
    var index: Int = 0
    var dimensionID: String = ""
    var categoryCount: Int = 0
    var perfect: Bool = false
    var cutShort: Bool = false
    var score: Int = 0
    var run: RunEntry?
    @Relationship(deleteRule: .cascade, inverse: \ItemEntry.round)
    var items: [ItemEntry]? = []

    init(result: RoundResult) {
        index = result.index
        dimensionID = result.dimensionID
        categoryCount = result.categoryCount
        perfect = result.perfect
        cutShort = result.cutShort
        score = result.score
        items = result.items.map(ItemEntry.init(result:))
    }

    var result: RoundResult {
        RoundResult(
            index: index,
            dimensionID: dimensionID,
            categoryCount: categoryCount,
            perfect: perfect,
            cutShort: cutShort,
            score: score,
            items: (items ?? []).sorted { $0.itemIndex < $1.itemIndex }.map(\.result)
        )
    }
}

@Model
final class ItemEntry {
    var roundIndex: Int = 0
    var itemIndex: Int = 0
    var dimensionID: String = ""
    var attributes: [String: String] = [:]
    var expectedCategoryID: String = ""
    var answeredCategoryID: String?
    var correct: Bool = false
    var timedOut: Bool = false
    var reactionMilliseconds: Int?
    var windowMilliseconds: Int = 0
    var points: Int = 0
    var hold: Bool = false
    var round: RoundEntry?

    init(result: ItemResult) {
        roundIndex = result.roundIndex
        itemIndex = result.itemIndex
        dimensionID = result.dimensionID
        attributes = result.attributes
        expectedCategoryID = result.expectedCategoryID
        answeredCategoryID = result.answeredCategoryID
        correct = result.correct
        timedOut = result.timedOut
        reactionMilliseconds = result.reaction.map(Self.milliseconds)
        windowMilliseconds = Self.milliseconds(result.window)
        points = result.points
        hold = result.hold
    }

    var result: ItemResult {
        ItemResult(
            roundIndex: roundIndex,
            itemIndex: itemIndex,
            dimensionID: dimensionID,
            attributes: attributes,
            expectedCategoryID: expectedCategoryID,
            answeredCategoryID: answeredCategoryID,
            correct: correct,
            timedOut: timedOut,
            reaction: reactionMilliseconds.map { .milliseconds($0) },
            window: .milliseconds(windowMilliseconds),
            points: points,
            hold: hold
        )
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }
}
