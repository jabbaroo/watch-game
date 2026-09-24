/// One resolved item. Produced by the engine, persisted by the app.
public struct ItemResult: Codable, Sendable, Equatable {
    public var roundIndex: Int
    public var itemIndex: Int
    public var dimensionID: String
    public var attributes: [String: String]
    public var expectedCategoryID: String
    /// Nil for a timeout.
    public var answeredCategoryID: String?
    public var correct: Bool
    public var timedOut: Bool
    /// Nil for a timeout.
    public var reaction: Duration?
    public var window: Duration
    public var points: Int

    public init(roundIndex: Int, itemIndex: Int, dimensionID: String, attributes: [String: String],
                expectedCategoryID: String, answeredCategoryID: String?, correct: Bool, timedOut: Bool,
                reaction: Duration?, window: Duration, points: Int) {
        self.roundIndex = roundIndex
        self.itemIndex = itemIndex
        self.dimensionID = dimensionID
        self.attributes = attributes
        self.expectedCategoryID = expectedCategoryID
        self.answeredCategoryID = answeredCategoryID
        self.correct = correct
        self.timedOut = timedOut
        self.reaction = reaction
        self.window = window
        self.points = points
    }
}

/// One finished round, including one cut short by running out of lives.
public struct RoundResult: Codable, Sendable, Equatable {
    public var index: Int
    public var dimensionID: String
    public var categoryCount: Int
    public var perfect: Bool
    public var cutShort: Bool
    /// Item points plus any perfect-round bonus.
    public var score: Int
    public var items: [ItemResult]

    public init(index: Int, dimensionID: String, categoryCount: Int, perfect: Bool, cutShort: Bool, score: Int, items: [ItemResult]) {
        self.index = index
        self.dimensionID = dimensionID
        self.categoryCount = categoryCount
        self.perfect = perfect
        self.cutShort = cutShort
        self.score = score
        self.items = items
    }
}

public enum RunEndReason: String, Codable, Sendable {
    case completedAllRounds
    case outOfLives
    case quit
    /// Set by the app for a run interrupted by a process kill. The engine never produces it.
    case abandoned
}

/// Everything the engine knows about a finished run.
public struct RunSummary: Codable, Sendable, Equatable {
    public var seed: UInt64
    public var packID: String
    public var score: Int
    public var livesRemaining: Int
    public var endReason: RunEndReason
    public var rounds: [RoundResult]

    public init(seed: UInt64, packID: String, score: Int, livesRemaining: Int, endReason: RunEndReason, rounds: [RoundResult]) {
        self.seed = seed
        self.packID = packID
        self.score = score
        self.livesRemaining = livesRemaining
        self.endReason = endReason
        self.rounds = rounds
    }

    /// A run counts as complete only when it ended naturally.
    public var completed: Bool { endReason == .completedAllRounds || endReason == .outOfLives }

    /// Rounds that ran to the clock.
    public var roundsCompleted: Int { rounds.filter { !$0.cutShort }.count }
}
