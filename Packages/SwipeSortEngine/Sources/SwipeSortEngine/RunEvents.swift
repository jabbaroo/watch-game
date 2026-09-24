/// The item currently on screen.
public struct ActiveItem: Sendable, Equatable {
    public var index: Int
    public var item: Item
    public var expectedCategoryID: String
    public var expectedEdge: SwipeEdge
    public var shownAt: Duration
    public var deadline: Duration
    public var window: Duration
    /// Go, no-go: a hold item must be left alone until its window closes.
    public var isHold: Bool

    public init(index: Int, item: Item, expectedCategoryID: String, expectedEdge: SwipeEdge, shownAt: Duration, deadline: Duration, window: Duration, isHold: Bool = false) {
        self.index = index
        self.item = item
        self.expectedCategoryID = expectedCategoryID
        self.expectedEdge = expectedEdge
        self.shownAt = shownAt
        self.deadline = deadline
        self.window = window
        self.isHold = isHold
    }
}

public enum ItemOutcome: Sendable, Equatable {
    case correct(points: Int, streak: Int)
    case wrong
    case timedOut
    /// A hold item left alone until its window closed: correct, scored without a speed bonus.
    case held(points: Int, streak: Int)
    /// A hold item that was flicked: wrong, costs a life.
    case falseAlarm
}

/// The engine says when feedback happens; the app's services decide what it feels and sounds like.
public enum FeedbackCue: Sendable, Equatable {
    case correct(streak: Int)
    case streakMilestone(streak: Int)
    case wrong
    case timedOut
    case lifeEarned
    case roundStarted
    case perfectRound
    case runEnded
}

public enum RunEvent: Sendable, Equatable {
    case startRun
    case startRound
    case answer(SwipeEdge)
    /// "Time may have passed." Handles timeouts, the inter-item gap and the round clock.
    case tick
    case pause
    case resume
    case quit
}

public indirect enum RunPhase: Sendable, Equatable {
    case notStarted
    case roundIntro(RoundPlan)
    case playing(ActiveItem)
    case betweenItems(nextItemAt: Duration)
    case paused(resuming: RunPhase, pausedAt: Duration)
    case finished(RunSummary)
}

public enum RunEffect: Sendable, Equatable {
    case roundIntro(RoundPlan)
    case roundStarted(RoundPlan)
    /// Also emitted on resume with shifted times. Views key entrance animations on `ActiveItem.index`.
    case itemShown(ActiveItem)
    case itemResolved(ItemResult, ItemOutcome)
    case livesChanged(Int)
    case scoreChanged(Int)
    case roundEnded(RoundResult)
    case runEnded(RunSummary)
    case feedback(FeedbackCue)
    /// The driver must send `.tick` no later than this time.
    case wake(at: Duration)
}
