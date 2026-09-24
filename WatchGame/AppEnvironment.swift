import Foundation
import Observation
import OSLog
import SwiftData
import SwipeSortEngine
import WidgetKit

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
        environment.refreshWidgetSummary()
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

    /// The built-in pack, always first in `packs`. The daily challenge uses it.
    var pack: ContentPack { packs[0] }

    func pack(id: String) -> ContentPack? {
        packs.first { $0.id == id }
    }

    /// The pack free play uses: the stored choice when it is installed, otherwise the built-in pack.
    var selectedPack: ContentPack {
        let stored = UserDefaults.standard.string(forKey: AppSettings.packID)
        return stored.flatMap(pack(id:)) ?? pack
    }

    func applySettings(from defaults: UserDefaults = .standard) {
        haptics.isEnabled = defaults.bool(forKey: AppSettings.hapticsEnabled)
        sound.isEnabled = defaults.bool(forKey: AppSettings.soundsEnabled)
    }

    /// Creates and stores a new session. A random seed for a normal run, the day's seed for the daily.
    /// Free play uses `packID` when given, else the selected pack; the daily always uses the built-in pack.
    @discardableResult
    func startRun(daily: Bool, packID: String? = nil, now: Date = .now) -> GameSession {
        var pack = daily ? self.pack : (packID.flatMap(self.pack(id:)) ?? selectedPack)
        #if DEBUG
        // UI tests pass "-debugPack <id>" to force a pack.
        if let debugID = UserDefaults.standard.string(forKey: "debugPack"), let debugPack = self.pack(id: debugID) {
            pack = debugPack
        }
        #endif
        let dayKey = daily ? DailySeed.dayKey(for: now) : nil
        let seed = daily ? DailySeed.seed(forDayKey: dayKey!) : UInt64.random(in: .min ... .max)
        let session = GameSession(pack: pack, seed: seed, isDaily: daily, dailyKey: dayKey,
                                  haptics: haptics, sound: sound, history: history, startedAt: now)
        self.session = session
        session.start()
        #if DEBUG
        // UI tests and the layout pass pass "-debugStartRound N" to open the run at round N.
        let target = UserDefaults.standard.integer(forKey: "debugStartRound")
        while target > 1, session.roundNumber < target, session.screen == .roundIntro {
            session.startRound()
            session.debugExpireRoundClock()
        }
        #endif
        return session
    }
}

extension AppEnvironment {
    private static let widgetLogger = Logger(subsystem: "com.pynto.sortsprint", category: "widget")

    /// Writes the widget summary and asks WidgetKit to refresh. Safe to call often.
    func refreshWidgetSummary(now: Date = .now) {
        let key = DailySeed.dayKey(for: now)
        let summary = WidgetSummary(
            dailyKey: key,
            dailyPlayedToday: history.hasCompletedDaily(dayKey: key),
            dailyStreak: history.dailyStreak(today: now),
            usualPlayHour: usualPlayHour()
        )
        if summary.save() {
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            Self.widgetLogger.error("App Group container unavailable; widget summary not written")
        }
    }

    /// Most common start hour over the last 30 completed runs, when there are at least 3.
    /// Ties resolve to the earliest hour.
    func usualPlayHour(calendar: Calendar = .current) -> Int? {
        let runs = history.completedRuns(limit: 30)
        guard runs.count >= 3 else { return nil }
        let counts = Dictionary(grouping: runs) { calendar.component(.hour, from: $0.startedAt) }
            .mapValues(\.count)
        return counts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key
    }
}
