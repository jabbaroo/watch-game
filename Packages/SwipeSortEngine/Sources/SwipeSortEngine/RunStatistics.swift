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

public struct ConfusionPair: Sendable, Equatable {
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
    public var wrongSwipeCount: Int
    public var timeoutCount: Int
    /// In the order dimensions were first played.
    public var errorsByDimension: [DimensionErrorRate]
    /// Sorted by count descending, then expected id, then answered id.
    public var confusionPairs: [ConfusionPair]
    /// Over correct items only.
    public var meanReaction: Duration?
    /// Mean over qualifying rounds of (mean of first `leadingItemCount` correct reactions
    /// minus mean of the remaining correct reactions). Nil when no round qualifies.
    public var switchCost: Duration?

    public var accuracy: Double? {
        resolvedCount > 0 ? Double(correctCount) / Double(resolvedCount) : nil
    }

    public static func compute(rounds: [RoundResult], leadingItemCount: Int = 3, minimumCorrectItems: Int = 6) -> RunStatistics {
        let items = rounds.flatMap(\.items)
        let correct = items.filter(\.correct)
        let wrong = items.filter { !$0.correct && !$0.timedOut }
        let timeouts = items.filter(\.timedOut)

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

        return RunStatistics(
            resolvedCount: items.count,
            correctCount: correct.count,
            wrongSwipeCount: wrong.count,
            timeoutCount: timeouts.count,
            errorsByDimension: dimensionOrder.compactMap { errorsByDimension[$0] },
            confusionPairs: confusionPairs,
            meanReaction: mean(correct.compactMap(\.reaction)),
            switchCost: mean(switchCosts)
        )
    }

    static func mean(_ durations: [Duration]) -> Duration? {
        guard !durations.isEmpty else { return nil }
        return durations.reduce(.zero, +) / durations.count
    }
}
