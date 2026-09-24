import SwiftUI
import SwipeSortEngine

/// Category labels pinned to the active edges. When `tapToSort` is on each label is a
/// 44-point tap target; otherwise labels are decoration and swipes carry the input.
struct EdgeLabelsView: View {
    var labels: [SwipeEdge: String]
    var highlighted: SwipeEdge?
    var tapToSort: Bool
    var fontSize: CGFloat = 13
    var onTap: (SwipeEdge) -> Void

    var body: some View {
        ZStack {
            ForEach(SwipeEdge.allCases, id: \.self) { edge in
                if let text = labels[edge] {
                    label(text, edge: edge)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: edge))
                }
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private func label(_ text: String, edge: SwipeEdge) -> some View {
        let core = Text(text)
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(highlighted == edge ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.14)))
            .scaleEffect(highlighted == edge ? 1.12 : 1)
            .animation(.spring(duration: 0.25), value: highlighted == edge)
        if tapToSort {
            Button { onTap(edge) } label: { core.frame(minWidth: 44, minHeight: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Sort as \(text)"))
        } else {
            core.accessibilityHidden(true)
        }
    }

    private func alignment(for edge: SwipeEdge) -> Alignment {
        switch edge {
        case .up: .top
        case .down: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }
}

#Preview {
    EdgeLabelsView(labels: [.left: "Red", .right: "Blue", .up: "Green"], highlighted: .right, tapToSort: true) { _ in }
        .background(.black)
}
