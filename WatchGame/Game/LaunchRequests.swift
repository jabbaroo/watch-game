import Foundation
import Observation

/// Requests that arrive from outside the UI (the widget deep link, the App Intent)
/// and are consumed by Home when it is safe to start a run.
@MainActor
@Observable
final class LaunchRequests {
    static let shared = LaunchRequests()

    private(set) var dailyRequested = false

    func requestDaily() {
        dailyRequested = true
    }

    /// Returns true once per request, then clears it.
    func takeDailyRequest() -> Bool {
        defer { dailyRequested = false }
        return dailyRequested
    }

    static func isDailyURL(_ url: URL) -> Bool {
        url.scheme == "swipesort" && url.host() == "daily"
    }
}
