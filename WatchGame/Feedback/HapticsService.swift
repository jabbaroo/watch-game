import WatchKit
import SwipeSortEngine

@MainActor
protocol HapticsService: AnyObject {
    func play(_ cue: FeedbackCue)
}

extension FeedbackCue {
    /// The one haptic a cue maps to (spec 5.1). Nil means no haptic.
    var hapticType: WKHapticType? {
        switch self {
        case .correct: .click
        case .streakMilestone: .success
        case .wrong, .timedOut: .failure
        case .lifeEarned: .directionUp
        case .roundStarted: .start
        case .runEnded: .stop
        case .perfectRound: nil
        }
    }
}

@MainActor
final class WatchHaptics: HapticsService {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func play(_ cue: FeedbackCue) {
        guard isEnabled, let type = cue.hapticType else { return }
        WKInterfaceDevice.current().play(type)
    }
}

@MainActor
final class SilentHaptics: HapticsService {
    func play(_ cue: FeedbackCue) {}
}
