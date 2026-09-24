import Testing
@testable import WatchGame

@Suite struct DurationFormattingTests {
    @Test func secondsWithTwoDecimals() {
        #expect(Duration.milliseconds(482).secondsText == "0.48 s")
        #expect(Duration.milliseconds(1250).secondsText == "1.25 s")
        #expect(Duration.zero.secondsText == "0.00 s")
    }

    @Test func signedMillisecondsForSwitchCost() {
        #expect(Duration.milliseconds(180).signedMillisecondsText == "+180 ms")
        #expect(Duration.milliseconds(-40).signedMillisecondsText == "-40 ms")
    }
}
