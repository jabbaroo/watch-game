@testable import SwipeSortEngine

/// Drives a RunState with an explicit clock so tests read like a script.
struct RunHarness {
    var state: RunState
    var now: Duration = .zero
    var effects: [RunEffect] = []

    init(seed: UInt64 = 1, configuration: RunConfiguration = .standard, pack: ContentPack = .shapesAndColours) {
        state = RunState(pack: pack, configuration: configuration, seed: seed)
    }

    @discardableResult
    mutating func send(_ event: RunEvent, after delay: Duration = .zero) -> [RunEffect] {
        now += delay
        let produced = state.apply(event, at: now)
        effects += produced
        return produced
    }

    var activeItem: ActiveItem? {
        if case .playing(let active) = state.phase { return active }
        return nil
    }

    mutating func startRunAndRound() {
        send(.startRun)
        send(.startRound)
    }

    /// Answers the current item correctly after `reaction`, then ticks through the gap so the next item is showing.
    mutating func answerCorrectly(reaction: Duration = .milliseconds(500)) {
        guard let active = activeItem else { preconditionFailure("No active item") }
        send(.answer(active.expectedEdge), after: reaction)
        advanceToNextItem()
    }

    /// Answers with a mapped edge that is not the expected one.
    mutating func answerWrong(reaction: Duration = .milliseconds(500)) {
        guard let active = activeItem else { preconditionFailure("No active item") }
        let wrongEdge = state.currentPlan.mapping.edges.first { $0 != active.expectedEdge }!
        send(.answer(wrongEdge), after: reaction)
        advanceToNextItem()
    }

    mutating func advanceToNextItem() {
        if case .betweenItems(let nextItemAt) = state.phase {
            send(.tick, after: nextItemAt - now)
        }
    }

    /// Lets the round clock run out.
    @discardableResult
    mutating func finishRoundByClock() -> [RunEffect] {
        let remaining = state.roundTimeRemaining(at: now)
        return send(.tick, after: remaining)
    }

    func contains(_ cue: FeedbackCue, in produced: [RunEffect]) -> Bool {
        produced.contains(.feedback(cue))
    }
}
