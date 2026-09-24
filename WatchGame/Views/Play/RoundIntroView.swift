import SwiftUI
import SwipeSortEngine

/// Shows the next rule and edge mapping, then auto-starts after 2.5 seconds or on tap.
/// The countdown stops while the scene is inactive or the display is dimmed.
struct RoundIntroView: View {
    let session: GameSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var countdownStart: Date?

    private let countdown: Duration = .milliseconds(2500)
    private var isActive: Bool { scenePhase == .active && !isLuminanceReduced }

    var body: some View {
        let plan = session.currentPlan
        ZStack {
            VStack(spacing: 6) {
                Text("Round \(session.roundNumber) of \(session.roundCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Sort by \(session.dimensionName(for: plan))")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                mappingPreview(plan)
                    .frame(height: 70)
                HStack(spacing: 12) {
                    LivesView(lives: session.lives, maximum: session.maximumLives)
                    Text(session.score, format: .number)
                        .font(.system(.footnote, design: .rounded).monospacedDigit())
                }
            }
            .padding(.horizontal, 8)
            if session.lastRound?.perfect == true {
                ConfettiView()
            }
            countdownRing
        }
        .contentShape(Rectangle())
        .onTapGesture { session.startRound() }
        .task(id: isActive) {
            guard isActive else { countdownStart = nil; return }
            countdownStart = Date()
            try? await Task.sleep(for: countdown)
            guard !Task.isCancelled, isActive, session.screen == .roundIntro else { return }
            session.startRound()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Double tap to start the round now"))
    }

    private var countdownRing: some View {
        TimelineView(.animation) { context in
            let elapsed = countdownStart.map { context.date.timeIntervalSince($0) } ?? 0
            let fraction = max(0, 1 - elapsed / (countdown / .seconds(1)))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
        }
        .allowsHitTesting(false)
    }

    private func mappingPreview(_ plan: RoundPlan) -> some View {
        var labels: [SwipeEdge: String] = [:]
        for (edge, category) in plan.mapping.categoryByEdge {
            labels[edge] = session.categoryLabel(category, in: plan)
        }
        return EdgeLabelsView(labels: labels, highlighted: nil, tapToSort: false) { _ in }
            .scaleEffect(0.85)
    }
}

struct LivesView: View {
    var lives: Int
    var maximum: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maximum, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundStyle(index < lives ? Color.red : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .animation(.default, value: lives)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(lives) of \(maximum) lives"))
    }
}
