import AVFoundation
import OSLog
import SwipeSortEngine

/// Every bundled sound. watchOS has no time-pitch audio unit, so the correct sound
/// ships as 13 pre-rendered variants, one per semitone from 0 to 12.
enum SoundAsset: Hashable, Sendable {
    case correct(semitones: Int)
    case wrong
    case timeout
    case roundStart
    case perfect
    case runEnd

    static let maximumSemitones = 12

    static var allCases: [SoundAsset] {
        (0...maximumSemitones).map { .correct(semitones: $0) } + [.wrong, .timeout, .roundStart, .perfect, .runEnd]
    }

    var fileName: String {
        switch self {
        case .correct(let semitones): String(format: "correct-%02d", semitones)
        case .wrong: "wrong"
        case .timeout: "timeout"
        case .roundStart: "roundStart"
        case .perfect: "perfect"
        case .runEnd: "runEnd"
        }
    }
}

extension FeedbackCue {
    /// The sound a cue plays (spec 5.2). The correct sound rises one semitone per
    /// streak step and is capped; the streak resets on any error, so the pitch does too.
    var sound: SoundAsset? {
        switch self {
        case .correct(let streak), .streakMilestone(let streak):
            .correct(semitones: min(max(streak - 1, 0), SoundAsset.maximumSemitones))
        case .wrong: .wrong
        case .timedOut: .timeout
        case .roundStarted: .roundStart
        case .perfectRound: .perfect
        case .runEnded: .runEnd
        case .lifeEarned: nil
        }
    }
}

@MainActor
protocol SoundService: AnyObject {
    func play(_ cue: FeedbackCue)
}

@MainActor
final class SilentSound: SoundService {
    func play(_ cue: FeedbackCue) {}
}

/// Plays the bundled sounds through an AVAudioEngine player node.
/// Any setup failure disables sound for the session and leaves gameplay untouched.
@MainActor
final class EngineSound: SoundService {
    private static let logger = Logger(subsystem: "com.pynto.swipesort", category: "sound")

    var isEnabled: Bool
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [SoundAsset: AVAudioPCMBuffer] = [:]
    private var isReady = false

    init(isEnabled: Bool = true, bundle: Bundle = .main) {
        self.isEnabled = isEnabled
        do {
            try configure(bundle: bundle)
            isReady = true
        } catch {
            Self.logger.error("Sound disabled: \(String(describing: error), privacy: .public)")
        }
    }

    private func configure(bundle: Bundle) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])
        try session.setActive(true)

        for asset in SoundAsset.allCases {
            guard let url = bundle.url(forResource: asset.fileName, withExtension: "wav") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try file.read(into: buffer)
            buffers[asset] = buffer
        }

        guard let format = buffers[.wrong]?.format else { throw CocoaError(.fileReadCorruptFile) }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
    }

    func play(_ cue: FeedbackCue) {
        guard isEnabled, isReady, let asset = cue.sound, let buffer = buffers[asset] else { return }
        if !engine.isRunning {
            do { try engine.start() } catch {
                Self.logger.error("Engine restart failed: \(String(describing: error), privacy: .public)")
                return
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }
}
