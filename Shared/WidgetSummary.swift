import Foundation

/// The small file the app writes for the widget. Both targets compile this file.
struct WidgetSummary: Codable, Equatable, Sendable {
    static let appGroup = "group.com.pynto.swipesort"
    static let fileName = "widget-summary.json"

    /// Local calendar day the summary describes, "yyyy-MM-dd".
    var dailyKey: String
    var dailyPlayedToday: Bool
    var dailyStreak: Int
    var usualPlayHour: Int?

    struct DisplayState: Equatable, Sendable {
        var playedToday: Bool
        var streak: Int
    }

    /// Derives what to show on `date` without trusting the flags verbatim (spec 8.1).
    func displayState(on date: Date, calendar: Calendar = .current) -> DisplayState {
        let today = Self.dayKey(for: date, calendar: calendar)
        if dailyKey == today {
            return DisplayState(playedToday: dailyPlayedToday, streak: dailyStreak)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
           dailyKey == Self.dayKey(for: yesterday, calendar: calendar), dailyPlayedToday {
            return DisplayState(playedToday: false, streak: dailyStreak)
        }
        return DisplayState(playedToday: false, streak: 0)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: fileName)
    }

    static func load() -> WidgetSummary? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }

    /// Returns false when the App Group container is unavailable.
    @discardableResult
    func save() -> Bool {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
