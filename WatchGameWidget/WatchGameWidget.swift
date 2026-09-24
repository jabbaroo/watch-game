import RelevanceKit
import SwiftUI
import WidgetKit

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
