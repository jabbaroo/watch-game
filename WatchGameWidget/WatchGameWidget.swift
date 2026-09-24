import RelevanceKit
import SwiftUI
import WidgetKit

struct DailyEntry: TimelineEntry {
    let date: Date
    let state: WidgetSummary.DisplayState
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, state: .init(playedToday: false, streak: 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let now = Date.now
        var entries = [entry(for: now)]
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            entries.append(entry(for: midnight))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    /// Hints the Smart Stack to surface the widget around the player's usual play hour.
    func relevance() async -> WidgetRelevance<Void> {
        guard let hour = WidgetSummary.load()?.usualPlayHour,
              let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)
        else { return WidgetRelevance([]) }
        let windowStart = start.addingTimeInterval(-30 * 60)
        let windowEnd = windowStart.addingTimeInterval(60 * 60)
        return WidgetRelevance([WidgetRelevanceAttribute(context: .date(from: windowStart, to: windowEnd))])
    }

    private func entry(for date: Date) -> DailyEntry {
        let summary = WidgetSummary.load() ?? WidgetSummary(dailyKey: "", dailyPlayedToday: false, dailyStreak: 0, usualPlayHour: nil)
        return DailyEntry(date: date, state: summary.displayState(on: date))
    }
}

struct DailyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.state.playedToday ? "checkmark" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(entry.state.streak)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        default:
            HStack(spacing: 8) {
                Image(systemName: entry.state.playedToday ? "checkmark.circle.fill" : "square.grid.2x2.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.state.playedToday ? "Daily done" : "Play today's challenge")
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.state.streak == 1 ? "1 day streak" : "\(entry.state.streak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

@main
struct WatchGameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pynto.sortsprint.daily", provider: DailyProvider()) { entry in
            DailyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "sortsprint://daily"))
        }
        .configurationDisplayName("Daily challenge")
        .description("Today's status and your streak.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
