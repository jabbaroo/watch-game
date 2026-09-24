import Foundation
import Observation
import SwipeSortEngine

/// Drives one run: owns the `RunState`, supplies it with time, and turns its effects
/// into view state, feedback and history writes.
@MainActor
@Observable
final class GameSession {
    enum Screen: Equatable {
        case roundIntro, playing, paused, results
    }

    struct ResolvedItem: Equatable {
        var item: ActiveItem
        var outcome: ItemOutcome
    }

    let pack: ContentPack
    let isDaily: Bool
    let dailyKey: String?
    let startedAt: Date

    private(set) var state: RunState
    /// The item on screen, nil during the inter-item gap and outside play.
    private(set) var activeItem: ActiveItem?
    /// The last resolved item, kept through the gap so views can animate its outcome.
    private(set) var resolvedItem: ResolvedItem?
    /// The last finished round, for the interstitial and the results screen.
    private(set) var lastRound: RoundResult?
    private(set) var summary: RunSummary?
    /// Whether `summary.score` beat every completed run recorded before this one.
    private(set) var isNewBest = false

    private let clock = ContinuousClock()
    private let epoch: ContinuousClock.Instant
    private var wakeTask: Task<Void, Never>?
    private let haptics: any HapticsService
    private let sound: any SoundService
    private let history: HistoryStore
    private let runEntry: RunEntry
    private let previousBest: Int?

    init(pack: ContentPack, seed: UInt64, isDaily: Bool, dailyKey: String?,
         configuration: RunConfiguration = .standard,
         haptics: any HapticsService, sound: any SoundService, history: HistoryStore,
         startedAt: Date = .now) {
        self.pack = pack
        self.isDaily = isDaily
        self.dailyKey = dailyKey
        self.startedAt = startedAt
        self.haptics = haptics
        self.sound = sound
        self.history = history
        state = RunState(pack: pack, configuration: configuration, seed: seed)
        epoch = clock.now
        previousBest = history.bestScore()
        runEntry = history.beginRun(packID: pack.id, isDaily: isDaily, dailyKey: dailyKey, seed: seed, startedAt: startedAt)
    }

    // MARK: - View state

    var screen: Screen {
        switch state.phase {
        case .notStarted, .roundIntro: .roundIntro
        case .playing, .betweenItems: .playing
        case .paused: .paused
        case .finished: .results
        }
    }

    var lives: Int { state.lives }
    var maximumLives: Int { state.configuration.maximumLives }
    var score: Int { state.score }
    var streak: Int { state.streak }
    var multiplier: Int { state.configuration.scoring.multiplier(streak: streak) }
    var roundNumber: Int { state.roundIndex + 1 }
    var roundCount: Int { state.plans.count }
    var currentPlan: RoundPlan { state.currentPlan }
    var roundDuration: Duration { state.configuration.roundDuration }
    var configuration: RunConfiguration { state.configuration }

    /// Time since the session started, on the same clock the engine sees.
    var now: Duration { clock.now - epoch }

    func roundTimeRemaining() -> Duration {
        state.roundTimeRemaining(at: now)
    }

    func dimensionName(for plan: RoundPlan) -> String {
        Localization.string(pack.dimension(id: plan.dimensionID)?.nameKey ?? plan.dimensionID)
    }

    func categoryLabel(_ categoryID: String, in plan: RoundPlan) -> String {
        let value = pack.dimension(id: plan.dimensionID)?.value(id: categoryID)
        return Localization.string(value?.labelKey ?? categoryID)
    }

    // MARK: - Player actions

    func start() { send(.startRun) }
    func startRound() { send(.startRound) }
    func answer(_ edge: SwipeEdge) { send(.answer(edge)) }

    func pause() {
        send(.pause)
        wakeTask?.cancel()
    }

    func resume() { send(.resume) }

    func quit() {
        wakeTask?.cancel()
        send(.quit)
    }

    /// Test hook: behaves as if the round clock ran out.
    func debugExpireRoundClock() {
        let effects = state.apply(.tick, at: now + roundDuration)
        handle(effects)
    }

    // MARK: - Engine plumbing

    private func send(_ event: RunEvent) {
        handle(state.apply(event, at: now))
    }

    private func handle(_ effects: [RunEffect]) {
        for effect in effects {
            switch effect {
            case .roundIntro:
                activeItem = nil
                resolvedItem = nil
            case .roundStarted:
                lastRound = nil
            case .itemShown(let item):
                activeItem = item
                resolvedItem = nil
            case .itemResolved(_, let outcome):
                if let item = activeItem {
                    resolvedItem = ResolvedItem(item: item, outcome: outcome)
                }
                activeItem = nil
            case .livesChanged, .scoreChanged:
                break
            case .roundEnded(let round):
                lastRound = round
                history.append(round, to: runEntry)
            case .runEnded(let summary):
                wakeTask?.cancel()
                activeItem = nil
                self.summary = summary
                isNewBest = summary.completed && summary.score > (previousBest ?? -1)
                history.finish(runEntry, summary: summary)
            case .feedback(let cue):
                haptics.play(cue)
                sound.play(cue)
            case .wake(let deadline):
                scheduleWake(at: deadline)
            }
        }
    }

    private func scheduleWake(at deadline: Duration) {
        wakeTask?.cancel()
        let instant = epoch + deadline
        wakeTask = Task { [weak self] in
            try? await Task.sleep(until: instant, clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.send(.tick)
        }
    }
}
