/// The whole game as a value. Apply events with the current time and act on the effects.
/// The engine never reads a clock; `now` is time elapsed since the caller's epoch.
public struct RunState: Sendable, Equatable {
    public let seed: UInt64
    public let pack: ContentPack
    public let configuration: RunConfiguration
    public let plans: [RoundPlan]

    public private(set) var phase: RunPhase = .notStarted
    public private(set) var roundIndex = 0
    public private(set) var lives: Int
    public private(set) var score = 0
    public private(set) var streak = 0
    public private(set) var completedRounds: [RoundResult] = []
    public private(set) var currentRoundItems: [ItemResult] = []

    private var sequencer: ItemSequencer?
    private var nextItemIndex = 0
    /// Categories of the items shown so far this round, for n-back rounds.
    private var shownCategories: [String] = []
    private var roundResumedAt: Duration = .zero
    private var roundElapsedBeforeResume: Duration = .zero

    public init(pack: ContentPack, configuration: RunConfiguration = .standard, seed: UInt64) {
        self.pack = pack
        self.configuration = configuration
        self.seed = seed
        var generator = SeededGenerator(seed: seed)
        self.plans = RoundPlanner.plan(pack: pack, configuration: configuration, using: &generator)
        self.lives = configuration.startingLives
    }

    public var currentPlan: RoundPlan { plans[roundIndex] }

    public var isRoundActive: Bool {
        switch phase {
        case .playing, .betweenItems, .paused: true
        default: false
        }
    }

    /// Time left on the round clock. Zero when no round is active.
    public func roundTimeRemaining(at now: Duration) -> Duration {
        guard isRoundActive else { return .zero }
        return max(configuration.roundDuration - roundElapsed(at: now), .zero)
    }

    // MARK: - Events

    public mutating func apply(_ event: RunEvent, at now: Duration) -> [RunEffect] {
        switch (phase, event) {
        case (.notStarted, .startRun):
            phase = .roundIntro(plans[0])
            return [.roundIntro(plans[0])]

        case (.roundIntro(let plan), .startRound):
            return beginRound(plan, at: now)

        case (.playing(let active), .answer(let edge)):
            if roundClockExpired(at: now) {
                return endRound(cutShort: false)
            }
            if now >= active.deadline {
                return active.isPrimer ? finishPrimer(active, at: now) : resolve(active, answeredEdge: nil, at: now)
            }
            guard !active.isPrimer, currentPlan.mapping.category(at: edge) != nil else {
                return [.wake(at: min(active.deadline, roundDeadline(at: now)))]
            }
            return resolve(active, answeredEdge: edge, at: now)

        case (.playing(let active), .tick):
            if roundClockExpired(at: now) {
                return endRound(cutShort: false)
            }
            if now >= active.deadline {
                return active.isPrimer ? finishPrimer(active, at: now) : resolve(active, answeredEdge: nil, at: now)
            }
            return [.wake(at: min(active.deadline, roundDeadline(at: now)))]

        case (.betweenItems(let nextItemAt), .tick):
            if roundClockExpired(at: now) {
                return endRound(cutShort: false)
            }
            if now >= nextItemAt {
                return showNextItem(at: now)
            }
            return [.wake(at: min(nextItemAt, roundDeadline(at: now)))]

        case (.playing, .pause), (.betweenItems, .pause):
            roundElapsedBeforeResume = roundElapsed(at: now)
            phase = .paused(resuming: phase, pausedAt: now)
            return []

        case (.paused(let resuming, let pausedAt), .resume):
            let shift = now - pausedAt
            roundResumedAt = now
            switch resuming {
            case .playing(var active):
                active.shownAt += shift
                active.deadline += shift
                phase = .playing(active)
                return [.itemShown(active), .wake(at: min(active.deadline, roundDeadline(at: now)))]
            case .betweenItems(let nextItemAt):
                let shifted = nextItemAt + shift
                phase = .betweenItems(nextItemAt: shifted)
                return [.wake(at: min(shifted, roundDeadline(at: now)))]
            default:
                phase = resuming
                return []
            }

        case (.finished, _), (.notStarted, _):
            return []

        case (_, .quit):
            currentRoundItems = []
            sequencer = nil
            return finish(reason: .quit)

        default:
            return []
        }
    }

    // MARK: - Round clock

    private func roundElapsed(at now: Duration) -> Duration {
        if case .paused = phase { return roundElapsedBeforeResume }
        return roundElapsedBeforeResume + (now - roundResumedAt)
    }

    private func roundClockExpired(at now: Duration) -> Bool {
        roundElapsed(at: now) >= configuration.roundDuration
    }

    private func roundDeadline(at now: Duration) -> Duration {
        now + roundTimeRemaining(at: now)
    }

    // MARK: - Transitions

    private mutating func beginRound(_ plan: RoundPlan, at now: Duration) -> [RunEffect] {
        sequencer = ItemSequencer(pack: pack, plan: plan, maximumConsecutiveSameTarget: configuration.maximumConsecutiveSameTarget)
        nextItemIndex = 0
        shownCategories = []
        streak = 0
        currentRoundItems = []
        roundResumedAt = now
        roundElapsedBeforeResume = .zero
        var effects: [RunEffect] = [.roundStarted(plan), .feedback(.roundStarted)]
        effects += showNextItem(at: now)
        return effects
    }

    private mutating func showNextItem(at now: Duration) -> [RunEffect] {
        guard var sequencer else { preconditionFailure("No sequencer for the current round") }
        let draw = sequencer.next()
        self.sequencer = sequencer
        // N-back: the first `depth` items are primers; after that the answer is the item shown `depth` steps earlier.
        let depth = currentPlan.backDepth
        let isPrimer = nextItemIndex < depth
        let expectedCategoryID = depth > 0 && !isPrimer ? shownCategories[nextItemIndex - depth] : draw.categoryID
        shownCategories.append(draw.categoryID)
        guard let edge = currentPlan.mapping.edge(for: expectedCategoryID) else {
            preconditionFailure("The planner maps every active category to an edge")
        }
        let window = configuration.itemWindow(roundIndex: roundIndex, streak: streak, isFirstItem: nextItemIndex == depth)
        let active = ActiveItem(
            index: nextItemIndex,
            item: draw.item,
            expectedCategoryID: expectedCategoryID,
            expectedEdge: edge,
            shownAt: now,
            deadline: now + window,
            window: window,
            isHold: draw.hold && !isPrimer,
            isPrimer: isPrimer
        )
        nextItemIndex += 1
        phase = .playing(active)
        return [.itemShown(active), .wake(at: min(active.deadline, roundDeadline(at: now)))]
    }

    /// A primer finished showing: no record, no score, no life. The UI gets a neutral outcome.
    private mutating func finishPrimer(_ active: ActiveItem, at now: Duration) -> [RunEffect] {
        let result = ItemResult(
            roundIndex: roundIndex, itemIndex: active.index, dimensionID: currentPlan.dimensionID,
            attributes: active.item.attributes, expectedCategoryID: active.expectedCategoryID,
            answeredCategoryID: nil, correct: true, timedOut: false, reaction: nil, window: active.window, points: 0
        )
        let nextItemAt = now + configuration.interItemDelay
        phase = .betweenItems(nextItemAt: nextItemAt)
        return [.itemResolved(result, .primed), .wake(at: min(nextItemAt, roundDeadline(at: now)))]
    }

    private mutating func resolve(_ active: ActiveItem, answeredEdge: SwipeEdge?, at now: Duration) -> [RunEffect] {
        let plan = currentPlan
        let answered = answeredEdge != nil
        let reaction: Duration? = answered ? now - active.shownAt : nil
        var points = 0
        let outcome: ItemOutcome
        let correct: Bool

        if active.isHold {
            // Go, no-go: leaving the item alone is right, flicking it is a false alarm.
            correct = !answered
            if correct {
                streak += 1
                points = configuration.scoring.pointsForHold(streak: streak)
                score += points
                outcome = .held(points: points, streak: streak)
            } else {
                streak = 0
                lives -= 1
                outcome = .falseAlarm
            }
        } else {
            correct = answeredEdge == active.expectedEdge
            if correct, let reaction {
                streak += 1
                points = configuration.scoring.points(streak: streak, reaction: reaction, window: active.window)
                score += points
                outcome = .correct(points: points, streak: streak)
            } else {
                streak = 0
                lives -= 1
                outcome = answered ? .wrong : .timedOut
            }
        }

        let result = ItemResult(
            roundIndex: roundIndex,
            itemIndex: active.index,
            dimensionID: plan.dimensionID,
            attributes: active.item.attributes,
            expectedCategoryID: active.expectedCategoryID,
            answeredCategoryID: answeredEdge.flatMap { plan.mapping.category(at: $0) },
            correct: correct,
            timedOut: !answered && !active.isHold,
            reaction: reaction,
            window: active.window,
            points: points,
            hold: active.isHold
        )
        currentRoundItems.append(result)

        var effects: [RunEffect] = [.itemResolved(result, outcome)]
        switch outcome {
        case .correct, .held:
            effects.append(.scoreChanged(score))
            let every = configuration.streakStep
            if every > 0, streak % every == 0 {
                effects.append(.feedback(.streakMilestone(streak: streak)))
            } else {
                effects.append(.feedback(.correct(streak: streak)))
            }
        case .wrong, .falseAlarm:
            effects.append(.livesChanged(lives))
            effects.append(.feedback(.wrong))
        case .timedOut:
            effects.append(.livesChanged(lives))
            effects.append(.feedback(.timedOut))
        case .primed:
            break // primers resolve in finishPrimer, never here
        }

        if lives <= 0 {
            effects += endRound(cutShort: true)
            return effects
        }

        let nextItemAt = now + configuration.interItemDelay
        phase = .betweenItems(nextItemAt: nextItemAt)
        effects.append(.wake(at: min(nextItemAt, roundDeadline(at: now))))
        return effects
    }

    private mutating func endRound(cutShort: Bool) -> [RunEffect] {
        let plan = currentPlan
        let perfect = !cutShort && !currentRoundItems.isEmpty && currentRoundItems.allSatisfy(\.correct)
        var roundScore = currentRoundItems.reduce(0) { $0 + $1.points }
        var effects: [RunEffect] = []

        if perfect {
            roundScore += configuration.scoring.perfectRoundBonus
            score += configuration.scoring.perfectRoundBonus
            effects.append(.scoreChanged(score))
            effects.append(.feedback(.perfectRound))
            if lives < configuration.maximumLives {
                lives += 1
                effects.append(.livesChanged(lives))
                effects.append(.feedback(.lifeEarned))
            }
        }

        let result = RoundResult(
            index: plan.index,
            dimensionID: plan.dimensionID,
            categoryCount: plan.activeCategoryIDs.count,
            perfect: perfect,
            cutShort: cutShort,
            score: roundScore,
            items: currentRoundItems,
            backDepth: plan.backDepth
        )
        completedRounds.append(result)
        currentRoundItems = []
        streak = 0
        sequencer = nil
        effects.append(.roundEnded(result))

        if cutShort {
            effects += finish(reason: .outOfLives)
        } else if roundIndex + 1 < plans.count {
            roundIndex += 1
            phase = .roundIntro(plans[roundIndex])
            effects.append(.roundIntro(plans[roundIndex]))
        } else {
            effects += finish(reason: .completedAllRounds)
        }
        return effects
    }

    private mutating func finish(reason: RunEndReason) -> [RunEffect] {
        let summary = RunSummary(
            seed: seed,
            packID: pack.id,
            score: score,
            livesRemaining: lives,
            endReason: reason,
            rounds: completedRounds
        )
        phase = .finished(summary)
        var effects: [RunEffect] = [.runEnded(summary)]
        if reason != .quit {
            effects.append(.feedback(.runEnded))
        }
        return effects
    }
}
