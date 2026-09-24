/// Every tunable number in the game. Change values here, not in the engine.
public struct RunConfiguration: Sendable, Equatable {
    public var roundCount = 8
    public var roundDuration: Duration = .seconds(40)
    public var interItemDelay: Duration = .milliseconds(250)

    /// Base item window per round, zero-based. Rounds past the end of the list reuse the last value.
    public var baseWindows: [Duration] = [
        .milliseconds(2000), .milliseconds(1900), .milliseconds(1750), .milliseconds(1600),
        .milliseconds(1450), .milliseconds(1300), .milliseconds(1150), .milliseconds(1000),
    ]
    /// Extra time on the first item of every round, so a rule switch costs reaction time rather than a life.
    public var firstItemGrace: Duration = .seconds(1)
    /// Every `streakStep` consecutive correct answers is a milestone: the window trims,
    /// the milestone haptic fires and (through `ScoringRules.multiplierStep`) the multiplier steps up.
    public var streakStep = 5
    public var streakTrimStep: Duration = .milliseconds(50)
    public var maximumStreakTrim: Duration = .milliseconds(200)
    public var minimumWindow: Duration = .milliseconds(850)

    public var startingLives = 3
    public var maximumLives = 3
    public var categoryRamp = [2, 2, 3, 3, 4, 4, 4, 4]
    public var maximumConsecutiveSameTarget = 2
    public var scoring = ScoringRules()

    public init() {}

    public static let standard = RunConfiguration()

    public func baseWindow(roundIndex: Int) -> Duration {
        if baseWindows.indices.contains(roundIndex) {
            return baseWindows[roundIndex]
        }
        return baseWindows.last ?? .seconds(2)
    }

    /// The time an item stays on screen. `roundIndex` is zero-based, `streak` is the
    /// number of consecutive correct answers so far this round, and the first item of a
    /// round gets `firstItemGrace` on top.
    public func itemWindow(roundIndex: Int, streak: Int, isFirstItem: Bool = false) -> Duration {
        let trimSteps = streakStep > 0 ? streak / streakStep : 0
        let trim = min(streakTrimStep * trimSteps, maximumStreakTrim)
        let window = max(baseWindow(roundIndex: roundIndex) - trim, minimumWindow)
        return isFirstItem ? window + firstItemGrace : window
    }

    public func categoryCount(roundIndex: Int) -> Int {
        if categoryRamp.indices.contains(roundIndex) {
            return categoryRamp[roundIndex]
        }
        return categoryRamp.last ?? 2
    }
}
