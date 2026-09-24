import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite struct GameSessionTests {
    func makeSession(seed: UInt64 = 1) throws -> (GameSession, HistoryStore, RecordingHaptics) {
        let container = try ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        let history = HistoryStore(container: container)
        let haptics = RecordingHaptics()
        let session = GameSession(pack: .shapesAndColours, seed: seed, isDaily: false, dailyKey: nil,
                                  haptics: haptics, sound: SilentSound(), history: history)
        return (session, history, haptics)
    }

    @Test func startShowsRoundIntroThenFirstItem() throws {
        let (session, _, haptics) = try makeSession()
        #expect(session.screen == .roundIntro)
        session.start()
        #expect(session.screen == .roundIntro)
        #expect(session.roundNumber == 1)
        session.startRound()
        #expect(session.screen == .playing)
        #expect(session.activeItem?.index == 0)
        #expect(haptics.cues == [.roundStarted])
    }

    @Test func answeringUpdatesScoreAndRecordsHaptic() throws {
        let (session, _, haptics) = try makeSession()
        session.start()
        session.startRound()
        let item = try #require(session.activeItem)
        session.answer(item.expectedEdge)
        #expect(session.score > 0)
        #expect(session.streak == 1)
        #expect(haptics.cues.last == .correct(streak: 1))
        #expect(session.resolvedItem?.outcome == .correct(points: session.score, streak: 1))
    }

    @Test func nextItemArrivesAfterGapWithoutExternalTick() async throws {
        let (session, _, _) = try makeSession()
        session.start()
        session.startRound()
        let first = try #require(session.activeItem)
        session.answer(first.expectedEdge)
        #expect(session.activeItem == nil)
        // The 250 ms gap ends on the session's own wake task; poll rather than sleep a fixed time,
        // because a loaded machine can starve the main actor for longer than the gap.
        #expect(await waitUntil(timeout: .seconds(3)) { session.activeItem?.index == 1 })
    }

    @Test func itemTimesOutWithoutExternalTick() async throws {
        let (session, _, haptics) = try makeSession()
        session.start()
        session.startRound()
        // The first item's window is 3 s (2 s plus grace); the next item cannot time out before 5.25 s.
        #expect(await waitUntil(timeout: .seconds(5)) { session.lives == 2 })
        #expect(session.lives == 2)
        #expect(haptics.cues.contains(.timedOut))
    }

    @Test func pauseStopsTheClock() async throws {
        let (session, _, _) = try makeSession()
        session.start()
        session.startRound()
        session.pause()
        #expect(session.screen == .paused)
        try await Task.sleep(for: .milliseconds(2600))
        #expect(session.lives == 3)
        session.resume()
        #expect(session.screen == .playing)
        #expect(session.activeItem?.index == 0)
    }

    @Test func quitFinishesRunAsIncomplete() throws {
        let (session, history, _) = try makeSession()
        session.start()
        session.startRound()
        session.quit()
        #expect(session.screen == .results)
        #expect(session.summary?.endReason == .quit)
        let runs = history.allRuns()
        #expect(runs.count == 1)
        #expect(runs[0].completed == false)
        #expect(runs[0].endedAt != nil)
    }

    @Test func roundsArePersistedAsTheyFinish() throws {
        let (session, history, _) = try makeSession()
        session.start()
        session.startRound()
        let item = try #require(session.activeItem)
        session.answer(item.expectedEdge)
        session.debugExpireRoundClock()
        #expect(session.screen == .roundIntro)
        #expect(session.roundNumber == 2)
        #expect(session.lastRound?.perfect == true)
        #expect(history.allRuns()[0].roundResults.count == 1)
    }
}

/// Polls `condition` on the main actor until it holds or `timeout` passes. Returns whether it held.
@MainActor
func waitUntil(timeout: Duration, _ condition: () -> Bool) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while clock.now < deadline {
        if condition() { return true }
        try? await Task.sleep(for: .milliseconds(50))
    }
    return condition()
}

@MainActor
final class RecordingHaptics: HapticsService {
    var cues: [FeedbackCue] = []
    func play(_ cue: FeedbackCue) { cues.append(cue) }
}
