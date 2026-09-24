import Foundation
import Testing
@testable import SwipeSortEngine

@Suite struct DailySeedTests {
    func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    let lateEvening = Date(timeIntervalSince1970: 1_790_292_600) // 2026-09-24T23:30:00Z

    @Test func dayKeyUsesLocalCalendarDate() {
        #expect(DailySeed.dayKey(for: lateEvening, calendar: calendar("UTC")) == "2026-09-24")
        #expect(DailySeed.dayKey(for: lateEvening, calendar: calendar("Europe/Paris")) == "2026-09-25")
        #expect(DailySeed.dayKey(for: lateEvening, calendar: calendar("America/Los_Angeles")) == "2026-09-24")
    }

    @Test func sameDayKeySameSeed() {
        #expect(DailySeed.seed(forDayKey: "2026-09-24") == DailySeed.seed(forDayKey: "2026-09-24"))
        #expect(DailySeed.seed(forDayKey: "2026-09-24") != DailySeed.seed(forDayKey: "2026-09-25"))
    }

    @Test func seedForDateMatchesSeedForKey() {
        let utc = calendar("UTC")
        #expect(DailySeed.seed(for: lateEvening, calendar: utc) == DailySeed.seed(forDayKey: "2026-09-24"))
    }

    @Test func dailyRunIsIdenticalForSameDay() {
        let seed = DailySeed.seed(forDayKey: "2026-09-24")
        var a = RunHarness(seed: seed)
        var b = RunHarness(seed: seed)
        a.startRunAndRound()
        b.startRunAndRound()
        #expect(a.state.plans == b.state.plans)
        #expect(a.activeItem?.item == b.activeItem?.item)
    }
}
