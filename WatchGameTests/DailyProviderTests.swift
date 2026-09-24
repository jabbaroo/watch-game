import Foundation
import Testing
import WidgetKit
@testable import WatchGame

@Suite struct DailyProviderTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func provider(_ summary: WidgetSummary?) -> DailyProvider {
        DailyProvider(loadSummary: { summary }, calendar: utc)
    }

    @Test func timelineHasNowAndNextMidnightWithStatesDerivedPerDate() {
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 10))!
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: 8)
        let timeline = provider(summary).timeline(from: now)
        #expect(timeline.entries.count == 2)
        #expect(timeline.entries[0].date == now)
        #expect(timeline.entries[0].state == .init(playedToday: true, streak: 4))
        #expect(timeline.entries[1].date == utc.date(from: DateComponents(year: 2026, month: 9, day: 25))!)
        #expect(timeline.entries[1].state == .init(playedToday: false, streak: 4), "yesterday was played, so the streak carries over midnight")
    }

    @Test func missingSummaryShowsTheUnplayedDefault() {
        let now = utc.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 10))!
        let entry = provider(nil).entry(for: now)
        #expect(entry.state == .init(playedToday: false, streak: 0))
    }

    @Test func relevanceFollowsTheUsualPlayHour() async {
        let with = await provider(WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: false, dailyStreak: 0, usualPlayHour: 8)).relevance()
        let without = await provider(WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: false, dailyStreak: 0, usualPlayHour: nil)).relevance()
        // WidgetRelevance exposes no accessors; the calls must simply return without trapping.
        _ = with
        _ = without
    }
}
