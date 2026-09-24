/// Every tunable number in the game. Change values here, not in the engine.
public struct RunConfiguration: Sendable, Equatable {
    public var roundCount = 8
    public var roundDuration: Duration = .seconds(45)
    public var interItemDelay: Duration = .milliseconds(250)

    public var initialWindow: Duration = .seconds(2)
    public var windowDecrementPerRound: Duration = .milliseconds(150)
    /// Every `streakStep` consecutive correct answers is a milestone: the window trims,
    /// the milestone haptic fires and (through `ScoringRules.multiplierStep`) the multiplier steps up.
    public var streakStep = 5
    public var streakTrimStep: Duration = .milliseconds(50)
    public var maximumStreakTrim: Duration = .milliseconds(300)
    public var minimumWindow: Duration = .milliseconds(800)

    public var startingLives = 3
    public var maximumLives = 3
    public var categoryRamp = [2, 2, 3, 3, 4, 4, 4, 4]
    public var maximumConsecutiveSameTarget = 2
    public var scoring = ScoringRules()

    public init() {}

    public static let standard = RunConfiguration()

    /// The time an item stays on screen. `roundIndex` is zero-based and
    /// `streak` is the number of consecutive correct answers so far this round.
    public func itemWindow(roundIndex: Int, streak: Int) -> Duration {
        let base = initialWindow - windowDecrementPerRound * roundIndex
        let trimSteps = streakStep > 0 ? streak / streakStep : 0
        let trim = min(streakTrimStep * trimSteps, maximumStreakTrim)
        return max(base - trim, minimumWindow)
    }

    public func categoryCount(roundIndex: Int) -> Int {
        if categoryRamp.indices.contains(roundIndex) {
            return categoryRamp[roundIndex]
        }
        return categoryRamp.last ?? 2
    }
}
