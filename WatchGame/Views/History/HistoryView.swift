import Charts
import SwiftUI
import SwipeSortEngine

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var summary: HistorySummary?

    var body: some View {
        List {
            if environment.history.isFallback {
                Section {
                    Text("History is unavailable on this watch right now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let summary {
                Section {
                    HStack {
                        tile("Best", summary.bestScore.map { "\($0)" } ?? "–")
                        tile("Runs", "\(summary.runsPlayed)")
                        tile("Streak", "\(summary.dailyStreak)")
                    }
                    .listRowBackground(Color.clear)
                }
                if summary.points.count >= 2 {
                    Section("Score") {
                        chart(summary.points, value: { Double($0.score) })
                    }
                    Section("Reaction time") {
                        chart(summary.points.filter { $0.reactionSeconds != nil }, value: { $0.reactionSeconds ?? 0 })
                    }
                    Section("Switch cost") {
                        chart(summary.points.filter { $0.switchCostMilliseconds != nil }, value: { $0.switchCostMilliseconds ?? 0 })
                    }
                }
                if let sharpest = summary.sharpestTimeOfDay {
                    Section {
                        LabeledContent("Sharpest", value: sharpest.title)
                    }
                }
                Section("Runs") {
                    if summary.recentRuns.isEmpty {
                        Text("Play a run to see it here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(summary.recentRuns, id: \.id) { run in
                        NavigationLink {
                            ResultsView(data: ResultsData(
                                summary: runSummary(run),
                                isDaily: run.isDaily,
                                isNewBest: false,
                                pack: environment.packs.first { $0.id == run.packID } ?? environment.pack
                            ))
                        } label: {
                            runRow(run)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .task { summary = HistorySummary.make(store: environment.history) }
    }

    private func tile(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chart(_ points: [HistorySummary.Point], value: @escaping (HistorySummary.Point) -> Double) -> some View {
        Chart(points) { point in
            LineMark(x: .value("Run", point.index), y: .value("Value", value(point)))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Run", point.index), y: .value("Value", value(point)))
                .symbolSize(20)
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .frame(height: 70)
        .accessibilityLabel(Text("Trend over the last \(points.count) runs"))
    }

    private func runRow(_ run: RunEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(run.startedAt, format: .dateTime.day().month().hour().minute())
                    .font(.footnote)
                HStack(spacing: 4) {
                    if run.isDaily {
                        Image(systemName: "calendar").font(.system(size: 9))
                    }
                    Text(Localization.string((environment.pack(id: run.packID) ?? environment.pack).nameKey))
                    Text(verbatim: "·")
                    Group {
                        if run.completed {
                            Text("\(run.roundsCompleted) rounds")
                        } else {
                            Text("Incomplete")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(run.score, format: .number)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(run.completed ? .primary : .secondary)
        }
    }

    private func runSummary(_ run: RunEntry) -> RunSummary {
        RunSummary(seed: UInt64(bitPattern: run.seed), packID: run.packID, score: run.score,
                   livesRemaining: run.livesRemaining, endReason: run.endReason, rounds: run.roundResults)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(AppEnvironment.preview())
    }
}
