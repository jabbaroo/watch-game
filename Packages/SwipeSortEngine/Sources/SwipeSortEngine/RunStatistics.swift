public struct DimensionErrorRate: Sendable, Equatable {
    public var dimensionID: String
    public var errors: Int
    public var total: Int

    public init(dimensionID: String, errors: Int, total: Int) {
        self.dimensionID = dimensionID
        self.errors = errors
        self.total = total
    }

    public var rate: Double { total > 0 ? Double(errors) / Double(total) : 0 }
}

public struct ConfusionPair: Sendable, Hashable {
    public var expectedCategoryID: String
    public var answeredCategoryID: String
    public var count: Int

    public init(expectedCategoryID: String, answeredCategoryID: String, count: Int) {
        self.expectedCategoryID = expectedCategoryID
        self.answeredCategoryID = answeredCategoryID
        self.count = count
    }
}

/// The per-run breakdown shown on Results and used by History.
public struct RunStatistics: Sendable, Equatable {
    public var resolvedCount: Int
    public var correctCount: Int
    /// Wrong flicks on items that should have been sorted. False alarms are counted separately.
    public var wrongSwipeCount: Int
    public var timeoutCount: Int
    /// Go, no-go: how many hold items appeared and how many were flicked by mistake.
    public var holdCount: Int
    public var falseAlarmCount: Int
    /// In the order dimensions were first played.
    public var errorsByDimension: [DimensionErrorRate]
    /// Sorted by count descending, then expected id, then answered id.
    public var confusionPairs: [ConfusionPair]
    /// Over correct items only.
    public var meanReaction: Duration?
    /// Mean over qualifying rounds of (mean of first `leadingItemCount` correct reactions
    /// minus mean of the remaining correct reactions). Nil when no round qualifies.
    public var switchCost: Duration?
    /// N-back: accuracy per depth over rounds played at that depth, depths above zero only.
    public var accuracyByDepth: [Int: Double]
    /// Stroop interference: mean correct reaction time on incongruent items minus congruent ones.
    /// An item is congruent when every dimension carries the same value id (a word in its own
    /// colour). Nil unless there are at least `minimumConflictItems` correct items of each kind.
    public var conflictCost: Duration?

    public var accuracy: Double? {
        resolvedCount > 0 ? Double(correctCount) / Double(resolvedCount) : nil
    }

    /// Share of hold items that were flicked. Nil when the run had no hold items.
    public var falseAlarmRate: Double? {
        holdCount > 0 ? Double(falseAlarmCount) / Double(holdCount) : nil
    }

    public static func compute(rounds: [RoundResult], leadingItemCount: Int = 3, minimumCorrectItems: Int = 6, minimumConflictItems: Int = 3) -> RunStatistics {
        let items = rounds.flatMap(\.items)
        let correct = items.filter(\.correct)
        let wrong = items.filter { !$0.correct && !$0.timedOut && !$0.hold }
        let timeouts = items.filter(\.timedOut)
        let holds = items.filter(\.hold)
        let falseAlarms = holds.filter { !$0.correct }

        var dimensionOrder: [String] = []
        var errorsByDimension: [String: DimensionErrorRate] = [:]
        for item in items {
            if errorsByDimension[item.dimensionID] == nil {
                dimensionOrder.append(item.dimensionID)
                errorsByDimension[item.dimensionID] = DimensionErrorRate(dimensionID: item.dimensionID, errors: 0, total: 0)
            }
            errorsByDimension[item.dimensionID]!.total += 1
            if !item.correct {
                errorsByDimension[item.dimensionID]!.errors += 1
            }
        }

        struct PairKey: Hashable { let expected: String; let answered: String }
        var pairCounts: [PairKey: Int] = [:]
        for item in wrong {
            guard let answered = item.answeredCategoryID else { continue }
            pairCounts[PairKey(expected: item.expectedCategoryID, answered: answered), default: 0] += 1
        }
        let confusionPairs = pairCounts
            .map { ConfusionPair(expectedCategoryID: $0.key.expected, answeredCategoryID: $0.key.answered, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                if a.expectedCategoryID != b.expectedCategoryID { return a.expectedCategoryID < b.expectedCategoryID }
                return a.answeredCategoryID < b.answeredCategoryID
            }

        let switchCosts: [Duration] = rounds.compactMap { round in
            let reactions = round.items.filter(\.correct).compactMap(\.reaction)
            guard reactions.count >= minimumCorrectItems,
                  let leading = mean(Array(reactions.prefix(leadingItemCount))),
                  let rest = mean(Array(reactions.dropFirst(leadingItemCount)))
            else { return nil }
            return leading - rest
        }

        var accuracyByDepth: [Int: Double] = [:]
        for (depth, group) in Dictionary(grouping: rounds.filter { $0.backDepth > 0 }, by: \.backDepth) {
            let depthItems = group.flatMap(\.items)
            if !depthItems.isEmpty {
                accuracyByDepth[depth] = Double(depthItems.filter(\.correct).count) / Double(depthItems.count)
            }
        }

        let congruent = correct.filter(\.isCongruent).compactMap(\.reaction)
        let incongruent = correct.filter { !$0.isCongruent }.compactMap(\.reaction)
        var conflictCost: Duration?
        if congruent.count >= minimumConflictItems, incongruent.count >= minimumConflictItems,
           let congruentMean = mean(congruent), let incongruentMean = mean(incongruent) {
            conflictCost = incongruentMean - congruentMean
        }

        return RunStatistics(
            resolvedCount: items.count,
            correctCount: correct.count,
            wrongSwipeCount: wrong.count,
            timeoutCount: timeouts.count,
            holdCount: holds.count,
            falseAlarmCount: falseAlarms.count,
            errorsByDimension: dimensionOrder.compactMap { errorsByDimension[$0] },
            confusionPairs: confusionPairs,
            meanReaction: mean(correct.compactMap(\.reaction)),
            switchCost: mean(switchCosts),
            accuracyByDepth: accuracyByDepth,
            conflictCost: conflictCost
        )
    }

    static func mean(_ durations: [Duration]) -> Duration? {
        guard !durations.isEmpty else { return nil }
        return durations.reduce(.zero, +) / durations.count
    }
}

public extension ItemResult {
    /// True when every dimension carries the same value id, for example the word "red" in red ink.
    var isCongruent: Bool {
        attributes.count >= 2 && Set(attributes.values).count == 1
    }
}
