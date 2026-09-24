import SwiftUI
import SwipeSortEngine

/// The playing state: round clock, lives and score, the item with its shrinking ring,
/// edge labels, swipe and tap input, and outcome animations.
struct PlayView: View {
    let session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AppStorage(AppSettings.tapToSort) private var tapToSort = false
    @AppStorage(AppSettings.colourHints) private var colourHints = false

    private let classifier = SwipeClassifier()
    @State private var highlightedEdge: SwipeEdge?
    @State private var flashEdge = false

    var body: some View {
        GeometryReader { geometry in
            let bounds = geometry.size
            // 40 and 41 mm watches are under 180 points wide; give the edge labels more room there.
            let compact = bounds.width < 180
            let itemSize = min(bounds.width, bounds.height) * (compact ? 0.32 : 0.36)
            ZStack {
                EdgeLabelsView(labels: labels, highlighted: highlightedEdge, tapToSort: tapToSort || voiceOver,
                               fontSize: compact ? 12 : 13) { edge in
                    session.answer(edge)
                }
                itemLayer(itemSize: itemSize)
                hud
                if flashEdge {
                    Rectangle()
                        .stroke(Color.red.opacity(0.8), lineWidth: 6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: bounds.width, height: bounds.height)
            .contentShape(Rectangle())
            .gesture(swipe(bounds: bounds))
            .onChange(of: session.resolvedItem) { _, resolved in
                animateOutcome(resolved)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Layers

    private var hud: some View {
        VStack {
            TimelineView(.animation(minimumInterval: 0.1)) { _ in
                let remaining = session.roundTimeRemaining()
                let fraction = max(0, min(1, remaining / session.roundDuration))
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: proxy.size.width * fraction, height: 3)
                }
                .frame(height: 3)
                .accessibilityHidden(true)
            }
            HStack {
                LivesView(lives: session.lives, maximum: session.maximumLives)
                Spacer()
                if session.multiplier > 1 {
                    Text("\(session.multiplier)x")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                        .transition(.scale.combined(with: .opacity))
                        .id(session.multiplier)
                }
                Text(session.score, format: .number)
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("Score \(session.score)"))
            }
            .padding(.horizontal, 6)
            .animation(.spring(duration: 0.3), value: session.multiplier)
            .animation(.default, value: session.score)
            Spacer()
            HStack {
                Spacer()
                Button {
                    session.pause()
                } label: {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 11))
                        .frame(width: 30, height: 22)
                }
                .buttonStyle(.plain)
                .handGestureShortcut(.primaryAction)
                .accessibilityLabel(Text("Pause"))
            }
            .padding(.trailing, 6)
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private func itemLayer(itemSize: CGFloat) -> some View {
        if let active = session.activeItem {
            ZStack {
                timerRing(for: active, size: itemSize + 18)
                ItemView(visual: active.item.visual, hint: hint(for: active.item), size: itemSize)
            }
            .id(active.index)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(session.categoryLabel(active.expectedCategoryID, in: session.currentPlan)))
            .accessibilityActions {
                ForEach(session.currentPlan.mapping.edges, id: \.self) { edge in
                    Button(labels[edge] ?? edge.rawValue) { session.answer(edge) }
                }
            }
        } else if let resolved = session.resolvedItem {
            OutcomeItemView(resolved: resolved, hint: hint(for: resolved.item.item), size: itemSize, reduceMotion: reduceMotion)
                .id(-1 - resolved.item.index)
                .accessibilityHidden(true)
        }
    }

    private func timerRing(for active: ActiveItem, size: CGFloat) -> some View {
        TimelineView(.animation) { _ in
            let remaining = max(.zero, active.deadline - session.now)
            let fraction = remaining / active.window
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(fraction < 0.3 ? Color.red : Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Input

    private var labels: [SwipeEdge: String] {
        var result: [SwipeEdge: String] = [:]
        for (edge, category) in session.currentPlan.mapping.categoryByEdge {
            result[edge] = session.categoryLabel(category, in: session.currentPlan)
        }
        return result
    }

    private func hint(for item: Item) -> String? {
        guard colourHints else { return nil }
        if case .word = item.visual { return nil }
        for dimension in session.pack.dimensions {
            if let valueID = item.attributes[dimension.id],
               let hintKey = dimension.value(id: valueID)?.hintKey {
                return Localization.string(hintKey)
            }
        }
        return nil
    }

    private func swipe(bounds: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onEnded { value in
                guard session.activeItem != nil,
                      let edge = classifier.edge(start: value.startLocation, translation: value.translation,
                                                 predictedTranslation: value.predictedEndTranslation, bounds: bounds)
                else { return }
                session.answer(edge)
            }
    }

    // MARK: - Outcome animation

    private func animateOutcome(_ resolved: GameSession.ResolvedItem?) {
        guard let resolved else { return }
        switch resolved.outcome {
        case .correct:
            highlightedEdge = resolved.item.expectedEdge
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                highlightedEdge = nil
            }
        case .wrong, .timedOut:
            withAnimation(.easeOut(duration: 0.1)) { flashEdge = true }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeIn(duration: 0.15)) { flashEdge = false }
            }
        }
    }
}

/// The just-resolved item during the inter-item gap: flies off, shakes, or dissolves.
private struct OutcomeItemView: View {
    let resolved: GameSession.ResolvedItem
    let hint: String?
    let size: CGFloat
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        ItemView(visual: resolved.item.item.visual, hint: hint, size: size)
            .modifier(OutcomeModifier(outcome: resolved.outcome, edge: resolved.item.expectedEdge,
                                      reduceMotion: reduceMotion, progress: progress))
            .onAppear {
                withAnimation(.easeIn(duration: 0.22)) { progress = 1 }
            }
    }
}

/// Interpolates `progress` from 0 to 1 and derives offset, scale and opacity from it,
/// so the shake and fly-off curves are sampled every frame rather than at the endpoints.
private struct OutcomeModifier: ViewModifier, Animatable {
    var outcome: ItemOutcome
    var edge: SwipeEdge
    var reduceMotion: Bool
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
    }

    private var offset: CGSize {
        switch outcome {
        case .correct:
            let distance: CGFloat = reduceMotion ? 0 : 90 * progress
            return CGSize(width: edge == .left ? -distance : edge == .right ? distance : 0,
                          height: edge == .up ? -distance : edge == .down ? distance : 0)
        case .wrong:
            let shake: CGFloat = reduceMotion ? 0 : sin(progress * .pi * 4) * 8 * (1 - progress)
            return CGSize(width: shake, height: 0)
        case .timedOut:
            return .zero
        }
    }

    private var scale: CGFloat {
        guard !reduceMotion else { return 1 }
        switch outcome {
        case .correct: return 1 + 0.15 * progress
        case .wrong: return 1
        case .timedOut: return 1 - 0.2 * progress
        }
    }

    private var opacity: Double {
        switch outcome {
        case .correct, .timedOut: 1 - progress
        case .wrong: 1 - progress * 0.6
        }
    }
}
