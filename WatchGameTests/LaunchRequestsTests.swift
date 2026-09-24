import Foundation
import Testing
@testable import WatchGame

@MainActor
@Suite struct LaunchRequestsTests {
    @Test func dailyRequestIsConsumedOnce() {
        let requests = LaunchRequests()
        #expect(!requests.takeDailyRequest())
        requests.requestDaily()
        #expect(requests.takeDailyRequest())
        #expect(!requests.takeDailyRequest())
    }

    @Test func dailyURLIsRecognised() {
        #expect(LaunchRequests.isDailyURL(URL(string: "swipesort://daily")!))
        #expect(!LaunchRequests.isDailyURL(URL(string: "swipesort://history")!))
        #expect(!LaunchRequests.isDailyURL(URL(string: "https://example.com/daily")!))
    }
}
