import Foundation

extension Duration {
    var seconds: Double { self / .seconds(1) }

    /// "0.48 s"
    var secondsText: String {
        String(format: "%.2f s", seconds)
    }

    /// "+180 ms" or "-40 ms"
    var signedMillisecondsText: String {
        let milliseconds = Int((self / .milliseconds(1)).rounded())
        return String(format: "%+d ms", milliseconds)
    }
}
