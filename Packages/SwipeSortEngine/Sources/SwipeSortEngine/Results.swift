/// One resolved item. Produced by the engine, persisted by the app.
public struct ItemResult: Sendable, Equatable {
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
    /// Go, no-go: the item was a hold item. Correct means it was left alone; incorrect means a false alarm.
    public var hold: Bool

    public init(roundIndex: Int, itemIndex: Int, dimensionID: String, attributes: [String: String],
                expectedCategoryID: String, answeredCategoryID: String?, correct: Bool, timedOut: Bool,
                reaction: Duration?, window: Duration, points: Int, hold: Bool = false) {
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
        self.hold = hold
    }
}

extension ItemResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case roundIndex, itemIndex, dimensionID, attributes, expectedCategoryID, answeredCategoryID
        case correct, timedOut, reaction, window, points, hold
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        roundIndex = try c.decode(Int.self, forKey: .roundIndex)
        itemIndex = try c.decode(Int.self, forKey: .itemIndex)
        dimensionID = try c.decode(String.self, forKey: .dimensionID)
        attributes = try c.decode([String: String].self, forKey: .attributes)
        expectedCategoryID = try c.decode(String.self, forKey: .expectedCategoryID)
        answeredCategoryID = try c.decodeIfPresent(String.self, forKey: .answeredCategoryID)
        correct = try c.decode(Bool.self, forKey: .correct)
        timedOut = try c.decode(Bool.self, forKey: .timedOut)
        reaction = try c.decodeIfPresent(Duration.self, forKey: .reaction)
        window = try c.decode(Duration.self, forKey: .window)
        points = try c.decode(Int.self, forKey: .points)
        hold = try c.decodeIfPresent(Bool.self, forKey: .hold) ?? false
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(roundIndex, forKey: .roundIndex)
        try c.encode(itemIndex, forKey: .itemIndex)
        try c.encode(dimensionID, forKey: .dimensionID)
        try c.encode(attributes, forKey: .attributes)
        try c.encode(expectedCategoryID, forKey: .expectedCategoryID)
        try c.encodeIfPresent(answeredCategoryID, forKey: .answeredCategoryID)
        try c.encode(correct, forKey: .correct)
        try c.encode(timedOut, forKey: .timedOut)
        try c.encodeIfPresent(reaction, forKey: .reaction)
        try c.encode(window, forKey: .window)
        try c.encode(points, forKey: .points)
        try c.encode(hold, forKey: .hold)
    }
}

/// One finished round, including one cut short by running out of lives.
public struct RoundResult: Sendable, Equatable {
    public var index: Int
    public var dimensionID: String
    public var categoryCount: Int
    public var perfect: Bool
    public var cutShort: Bool
    /// Item points plus any perfect-round bonus.
    public var score: Int
    public var items: [ItemResult]
    /// N-back depth the round was played at; 0 for plain sorting.
    public var backDepth: Int

    public init(index: Int, dimensionID: String, categoryCount: Int, perfect: Bool, cutShort: Bool, score: Int, items: [ItemResult], backDepth: Int = 0) {
        self.index = index
        self.dimensionID = dimensionID
        self.categoryCount = categoryCount
        self.perfect = perfect
        self.cutShort = cutShort
        self.score = score
        self.items = items
        self.backDepth = backDepth
    }
}

extension RoundResult: Codable {
    private enum CodingKeys: String, CodingKey {
        case index, dimensionID, categoryCount, perfect, cutShort, score, items, backDepth
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index = try c.decode(Int.self, forKey: .index)
        dimensionID = try c.decode(String.self, forKey: .dimensionID)
        categoryCount = try c.decode(Int.self, forKey: .categoryCount)
        perfect = try c.decode(Bool.self, forKey: .perfect)
        cutShort = try c.decode(Bool.self, forKey: .cutShort)
        score = try c.decode(Int.self, forKey: .score)
        items = try c.decode([ItemResult].self, forKey: .items)
        backDepth = try c.decodeIfPresent(Int.self, forKey: .backDepth) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(index, forKey: .index)
        try c.encode(dimensionID, forKey: .dimensionID)
        try c.encode(categoryCount, forKey: .categoryCount)
        try c.encode(perfect, forKey: .perfect)
        try c.encode(cutShort, forKey: .cutShort)
        try c.encode(score, forKey: .score)
        try c.encode(items, forKey: .items)
        try c.encode(backDepth, forKey: .backDepth)
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
