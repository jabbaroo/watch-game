import Foundation
import Testing
import WatchKit
import SwipeSortEngine
@testable import WatchGame

@Suite struct FeedbackMappingTests {
    @Test func hapticTableMatchesSpec() {
        #expect(FeedbackCue.correct(streak: 1).hapticType == .click)
        #expect(FeedbackCue.correct(streak: 4).hapticType == .click)
        #expect(FeedbackCue.streakMilestone(streak: 5).hapticType == .success)
        #expect(FeedbackCue.wrong.hapticType == .failure)
        #expect(FeedbackCue.timedOut.hapticType == .failure)
        #expect(FeedbackCue.lifeEarned.hapticType == .directionUp)
        #expect(FeedbackCue.roundStarted.hapticType == .start)
        #expect(FeedbackCue.runEnded.hapticType == .stop)
        #expect(FeedbackCue.perfectRound.hapticType == nil)
    }

    @Test func soundTableAndPitch() {
        #expect(FeedbackCue.correct(streak: 1).sound == .correct(semitones: 0))
        #expect(FeedbackCue.correct(streak: 2).sound == .correct(semitones: 0))
        #expect(FeedbackCue.correct(streak: 7).sound == .correct(semitones: 3))
        #expect(FeedbackCue.streakMilestone(streak: 20).sound == .correct(semitones: 9))
        #expect(FeedbackCue.correct(streak: 37).sound == .correct(semitones: 18))
        #expect(FeedbackCue.correct(streak: 60).sound == .correct(semitones: 18))
        #expect(FeedbackCue.wrong.sound == .wrong)
        #expect(FeedbackCue.timedOut.sound == .timeout)
        #expect(FeedbackCue.roundStarted.sound == .roundStart)
        #expect(FeedbackCue.perfectRound.sound == .perfect)
        #expect(FeedbackCue.runEnded.sound == .runEnd)
        #expect(FeedbackCue.lifeEarned.sound == nil)
    }

    @Test func everySoundAssetIsBundled() {
        #expect(SoundAsset.allCases.count == 24)
        for asset in SoundAsset.allCases {
            #expect(Bundle.main.url(forResource: asset.fileName, withExtension: "wav") != nil, "missing \(asset.fileName).wav")
        }
    }
}
