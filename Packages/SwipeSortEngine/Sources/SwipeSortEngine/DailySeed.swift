import Foundation

/// Turns a calendar day into a run seed so every play of a day's challenge is identical.
public enum DailySeed {
    /// "yyyy-MM-dd" in the given calendar's time zone.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// FNV-1a 64-bit hash of the day key.
    public static func seed(forDayKey key: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    public static func seed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        seed(forDayKey: dayKey(for: date, calendar: calendar))
    }
}
