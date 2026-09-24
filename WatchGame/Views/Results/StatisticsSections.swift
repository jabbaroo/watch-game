import SwiftUI
import SwipeSortEngine

/// The section 3.6 breakdown, shared by the results screen and history detail.
struct StatisticsSections: View {
    var statistics: RunStatistics
    var pack: ContentPack

    var body: some View {
        Section("Errors") {
            row("Wrong swipes", value: "\(statistics.wrongSwipeCount)")
            row("Timeouts", value: "\(statistics.timeoutCount)")
            ForEach(statistics.errorsByDimension, id: \.dimensionID) { entry in
                row(verbatim: dimensionName(entry.dimensionID), value: "\(entry.errors) of \(entry.total)")
            }
        }
        if !statistics.confusionPairs.isEmpty {
            Section("Mixed up") {
                ForEach(statistics.confusionPairs.prefix(3), id: \.self) { pair in
                    HStack {
                        Text("\(categoryLabel(pair.expectedCategoryID)) as \(categoryLabel(pair.answeredCategoryID))")
                            .lineLimit(2)
                        Spacer()
                        Text("\(pair.count)x")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        }
        Section("Speed") {
            row("Reaction", value: statistics.meanReaction?.secondsText ?? "–")
            row("Switch cost", value: statistics.switchCost?.signedMillisecondsText ?? "–")
        }
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.footnote)
    }

    private func row(verbatim title: String, value: String) -> some View {
        HStack {
            Text(verbatim: title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.footnote)
    }

    private func dimensionName(_ id: String) -> String {
        Localization.string(pack.dimension(id: id)?.nameKey ?? id)
    }

    private func categoryLabel(_ id: String) -> String {
        for dimension in pack.dimensions {
            if let value = dimension.value(id: id) {
                return Localization.string(value.labelKey)
            }
        }
        return id
    }
}
