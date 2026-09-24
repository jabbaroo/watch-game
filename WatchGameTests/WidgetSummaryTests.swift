import Foundation
import Testing
@testable import WatchGame

@Suite struct WidgetSummaryTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func day(_ day: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 10))!
    }

    @Test func displayStateForToday() {
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: 8)
        let state = summary.displayState(on: day(24), calendar: utc)
        #expect(state == WidgetSummary.DisplayState(playedToday: true, streak: 4))
    }

    @Test func displayStateTheMorningAfterAPlayedDay() {
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: nil)
        #expect(summary.displayState(on: day(25), calendar: utc) == WidgetSummary.DisplayState(playedToday: false, streak: 4))
    }

    @Test func displayStateAfterAMissedDayOrStaleFile() {
        let unplayed = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: false, dailyStreak: 4, usualPlayHour: nil)
        #expect(unplayed.displayState(on: day(25), calendar: utc) == WidgetSummary.DisplayState(playedToday: false, streak: 0))
        let stale = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: nil)
        #expect(stale.displayState(on: day(26), calendar: utc) == WidgetSummary.DisplayState(playedToday: false, streak: 0))
    }

    @Test func roundTripsThroughJSON() throws {
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: false, dailyStreak: 1, usualPlayHour: 21)
        let data = try JSONEncoder().encode(summary)
        #expect(try JSONDecoder().decode(WidgetSummary.self, from: data) == summary)
    }
}
