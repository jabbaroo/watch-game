import SwiftUI
import SwipeSortEngine

/// Full-screen host for a run. Switches between intro, play, pause and results,
/// and pauses play whenever the scene is not active or the display is dimmed.
struct RunView: View {
    let session: GameSession
    var onPlayAgain: () -> Void
    var onDismiss: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            switch session.screen {
            case .roundIntro:
                RoundIntroView(session: session)
            case .playing:
                PlayView(session: session)
            case .paused:
                PausedView(session: session, onQuit: onDismiss)
            case .results:
                if let summary = session.summary, summary.completed {
                    ResultsView(
                        data: ResultsData(summary: summary, isDaily: session.isDaily, isNewBest: session.isNewBest, pack: session.pack),
                        onPlayAgain: onPlayAgain,
                        onHome: onDismiss
                    )
                } else {
                    Color.clear.onAppear(perform: onDismiss)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pauseIfPlaying() }
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced { pauseIfPlaying() }
        }
    }

    private func pauseIfPlaying() {
        if session.screen == .playing {
            session.pause()
        }
    }
}
