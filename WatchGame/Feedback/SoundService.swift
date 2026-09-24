import AVFoundation
import OSLog
import SwipeSortEngine

/// Every bundled sound. watchOS has no time-pitch audio unit, so the correct sound
/// ships as 19 pre-rendered variants, one per semitone from 0 to 18.
enum SoundAsset: Hashable, Sendable {
    case correct(semitones: Int)
    case wrong
    case timeout
    case roundStart
    case perfect
    case runEnd

    static let maximumSemitones = 18

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
    /// The sound a cue plays (spec 5.2). The correct sound rises half a semitone per
    /// correct answer, capped at an octave and a half; the streak resets on any error, so the pitch does too.
    var sound: SoundAsset? {
        switch self {
        case .correct(let streak), .streakMilestone(let streak):
            .correct(semitones: min(max(streak - 1, 0) / 2, SoundAsset.maximumSemitones))
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

/// Plays the bundled sounds through an AVAudioEngine player node. The audio session and
/// engine run only while sound is enabled. Any setup failure disables sound for the session
/// and leaves gameplay untouched.
@MainActor
final class EngineSound: SoundService {
    private static let logger = Logger(subsystem: "com.pynto.sortsprint", category: "sound")

    var isEnabled: Bool {
        didSet {
            guard isEnabled != oldValue else { return }
            if isEnabled { startIfNeeded() } else { stop() }
        }
    }
    private let bundle: Bundle
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffers: [SoundAsset: AVAudioPCMBuffer] = [:]
    private var isConfigured = false
    private var isBroken = false

    init(isEnabled: Bool = true, bundle: Bundle = .main) {
        self.isEnabled = isEnabled
        self.bundle = bundle
        if isEnabled { startIfNeeded() }
    }

    private func startIfNeeded() {
        guard !isBroken else { return }
        do {
            if !isConfigured {
                try configure(bundle: bundle)
                isConfigured = true
            }
            try AVAudioSession.sharedInstance().setActive(true)
            if !engine.isRunning { try engine.start() }
        } catch {
            isBroken = true
            Self.logger.error("Sound disabled: \(String(describing: error), privacy: .public)")
        }
    }

    private func stop() {
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configure(bundle: Bundle) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [])

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
        for (asset, buffer) in buffers where buffer.format != format {
            throw SoundError.formatMismatch(asset.fileName)
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
    }

    enum SoundError: Error { case formatMismatch(String) }

    func play(_ cue: FeedbackCue) {
        guard isEnabled, let asset = cue.sound, let buffer = buffers[asset] else { return }
        if !engine.isRunning {
            startIfNeeded()
            guard engine.isRunning else { return }
        }
        // Rapid cues replace whatever is playing; the fanfare and the run-end sting queue behind it,
        // so a perfect final round is heard before the sting rather than cut off by it.
        let queues = cue == .perfectRound || cue == .runEnded
        player.scheduleBuffer(buffer, at: nil, options: queues ? [] : .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }
}
