import SwiftUI
import SwipeSortEngine

struct ResultsData {
    var summary: RunSummary
    var isDaily: Bool
    var isNewBest: Bool
    var pack: ContentPack = .shapesAndColours

    var statistics: RunStatistics { RunStatistics.compute(rounds: summary.rounds) }
}

/// Final score with the error breakdown. Also used by History for past runs.
struct ResultsView: View {
    var data: ResultsData
    var onPlayAgain: (() -> Void)?
    var onHome: (() -> Void)?

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    if data.isDaily {
                        Text("Daily challenge")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(data.summary.score, format: .number)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    if data.isNewBest {
                        Label("New best", systemImage: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                    HStack(spacing: 10) {
                        stat("Accuracy", data.statistics.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                        stat("Rounds", "\(data.summary.roundsCompleted) of \(data.summary.rounds.count)")
                        stat("Lives", "\(data.summary.livesRemaining)")
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .overlay {
                    if data.summary.rounds.last?.perfect == true {
                        ConfettiView()
                    }
                }
            }
            StatisticsSections(statistics: data.statistics, pack: data.pack)
            if onPlayAgain != nil || onHome != nil {
                Section {
                    if let onPlayAgain {
                        Button("Play again", action: onPlayAgain)
                            .buttonStyle(.borderedProminent)
                    }
                    if let onHome {
                        Button("Home", action: onHome)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(onHome == nil ? Text("Run") : Text("Results"))
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let rounds = (0..<8).map { index in
        RoundResult(index: index, dimensionID: index.isMultiple(of: 2) ? "colour" : "shape", categoryCount: 3, perfect: index == 7, cutShort: false, score: 900, items: [
            ItemResult(roundIndex: index, itemIndex: 0, dimensionID: "colour", attributes: [:], expectedCategoryID: "red", answeredCategoryID: "blue", correct: false, timedOut: false, reaction: .milliseconds(600), window: .seconds(2), points: 0),
            ItemResult(roundIndex: index, itemIndex: 1, dimensionID: "colour", attributes: [:], expectedCategoryID: "red", answeredCategoryID: "red", correct: true, timedOut: false, reaction: .milliseconds(450), window: .seconds(2), points: 138),
        ])
    }
    let summary = RunSummary(seed: 1, packID: "shapes-colours", score: 7200, livesRemaining: 2, endReason: .completedAllRounds, rounds: rounds)
    NavigationStack {
        ResultsView(data: ResultsData(summary: summary, isDaily: true, isNewBest: true), onPlayAgain: {}, onHome: {})
    }
}
