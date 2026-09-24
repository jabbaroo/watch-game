import Foundation
import RelevanceKit
import WidgetKit

// Compiled into both the app (for tests) and the widget extension.

nonisolated struct DailyEntry: TimelineEntry {
    let date: Date
    let state: WidgetSummary.DisplayState
}

/// Builds the daily widget's timeline from the summary file the app writes.
nonisolated struct DailyProvider: TimelineProvider {
    /// Injectable for tests; the widget reads the App Group file.
    var loadSummary: @Sendable () -> WidgetSummary? = { WidgetSummary.load() }
    var calendar: Calendar = .current

    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, state: .init(playedToday: false, streak: 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        completion(timeline(from: .now))
    }

    /// An entry for now and one at the next local midnight, each derived for its own date,
    /// so the status stays right across the day boundary without the app running.
    func timeline(from now: Date) -> Timeline<DailyEntry> {
        var entries = [entry(for: now)]
        if let midnight = calendar.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            entries.append(entry(for: midnight))
        }
        return Timeline(entries: entries, policy: .atEnd)
    }

    /// Hints the Smart Stack to surface the widget around the player's usual play hour.
    func relevance() async -> WidgetRelevance<Void> {
        guard let hour = loadSummary()?.usualPlayHour,
              let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: .now)
        else { return WidgetRelevance([]) }
        let window = DateInterval(start: start.addingTimeInterval(-30 * 60), duration: 60 * 60)
        return WidgetRelevance([WidgetRelevanceAttribute(context: .date(interval: window, kind: .scheduled))])
    }

    func entry(for date: Date) -> DailyEntry {
        let summary = loadSummary() ?? WidgetSummary(dailyKey: "", dailyPlayedToday: false, dailyStreak: 0, usualPlayHour: nil)
        return DailyEntry(date: date, state: summary.displayState(on: date, calendar: calendar))
    }
}
