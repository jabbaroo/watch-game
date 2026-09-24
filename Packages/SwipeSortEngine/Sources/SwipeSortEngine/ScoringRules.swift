public struct ScoringRules: Sendable, Equatable {
    public var basePoints = 100
    public var multiplierStep = 5
    public var maximumMultiplier = 4
    public var speedBonusMaximum = 50
    public var perfectRoundBonus = 500

    public init() {}

    /// Streak counts the current correct answer, so the first answer is streak 1.
    /// The multiplier steps up on every multiple of `multiplierStep`, so the fifth
    /// consecutive correct answer is the first to score double.
    public func multiplier(streak: Int) -> Int {
        guard streak >= 1, multiplierStep > 0 else { return 1 }
        return min(maximumMultiplier, 1 + streak / multiplierStep)
    }

    public func speedBonus(reaction: Duration, window: Duration) -> Int {
        guard window > .zero else { return 0 }
        let remaining = max(window - reaction, .zero)
        let fraction = remaining / window
        return Int((Double(speedBonusMaximum) * fraction).rounded())
    }

    public func points(streak: Int, reaction: Duration, window: Duration) -> Int {
        basePoints * multiplier(streak: streak) + speedBonus(reaction: reaction, window: window)
    }

    /// Points for leaving a hold item alone: base times multiplier, no speed bonus.
    public func pointsForHold(streak: Int) -> Int {
        basePoints * multiplier(streak: streak)
    }
}
