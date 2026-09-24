import SwiftData
import Foundation
import Observation
import SwipeSortEngine

/// Long-lived services, built once at launch and injected through the SwiftUI environment.
@MainActor
@Observable
final class AppEnvironment {
    let history: HistoryStore
    let haptics: WatchHaptics
    let sound: EngineSound
    let packs: [ContentPack]
    /// The run in progress, if any. Set by Home, cleared when the run screen is dismissed.
    var session: GameSession?

    init(history: HistoryStore, haptics: WatchHaptics, sound: EngineSound, packs: [ContentPack]) {
        self.history = history
        self.haptics = haptics
        self.sound = sound
        self.packs = packs
    }

    static func live() -> AppEnvironment {
        AppSettings.register()
        let history = HistoryStore.open()
        history.markAbandonedRuns()
        let defaults = UserDefaults.standard
        let environment = AppEnvironment(
            history: history,
            haptics: WatchHaptics(isEnabled: defaults.bool(forKey: AppSettings.hapticsEnabled)),
            sound: EngineSound(isEnabled: defaults.bool(forKey: AppSettings.soundsEnabled)),
            packs: PackLoader.loadPacks()
        )
        return environment
    }

    /// In-memory history and no audio, for previews.
    static func preview() -> AppEnvironment {
        let container = try! ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        return AppEnvironment(
            history: HistoryStore(container: container, isFallback: true),
            haptics: WatchHaptics(isEnabled: false),
            sound: EngineSound(isEnabled: false),
            packs: [.shapesAndColours]
        )
    }

    var pack: ContentPack { packs[0] }

    func applySettings(from defaults: UserDefaults = .standard) {
        haptics.isEnabled = defaults.bool(forKey: AppSettings.hapticsEnabled)
        sound.isEnabled = defaults.bool(forKey: AppSettings.soundsEnabled)
    }

    /// Creates and stores a new session. A random seed for a normal run, the day's seed for the daily.
    @discardableResult
    func startRun(daily: Bool, now: Date = .now) -> GameSession {
        let dayKey = daily ? DailySeed.dayKey(for: now) : nil
        let seed = daily ? DailySeed.seed(forDayKey: dayKey!) : UInt64.random(in: .min ... .max)
        let session = GameSession(pack: pack, seed: seed, isDaily: daily, dailyKey: dayKey,
                                  haptics: haptics, sound: sound, history: history, startedAt: now)
        self.session = session
        session.start()
        return session
    }
}
