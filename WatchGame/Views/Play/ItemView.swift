import SwiftUI
import SwipeSortEngine

/// Draws a pack item's visual at a given size, with an optional one-character hint overlay.
struct ItemView: View {
    var visual: Visual
    var hint: String?
    var size: CGFloat

    var body: some View {
        ZStack {
            switch visual {
            case let .shape(kind, colour):
                shape(kind)
                    .fill(Color(hex: colour))
                    .frame(width: size, height: size)
            case let .image(assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
            if let hint {
                Text(hint)
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.75))
                    .accessibilityHidden(true)
            }
        }
    }

    private func shape(_ kind: ShapeKind) -> AnyShape {
        switch kind {
        case .circle: AnyShape(Circle())
        case .square: AnyShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
        case .triangle: AnyShape(TriangleShape())
        case .star: AnyShape(StarShape())
        }
    }
}

nonisolated struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

nonisolated struct StarShape: Shape {
    var points = 5

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / Double(points) - .pi / 2
            let point = CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

extension Color {
    /// Parses "#RRGGBB" or "#RRGGBBAA". Falls back to grey for malformed input.
    init(hex: String) {
        var value: UInt64 = 0
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard Scanner(string: digits).scanHexInt64(&value), digits.count == 6 || digits.count == 8 else {
            self = .gray
            return
        }
        let alpha = digits.count == 8 ? Double(value & 0xFF) / 255 : 1
        let shift = digits.count == 8 ? 8 : 0
        self.init(
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview {
    HStack {
        ItemView(visual: .shape(kind: .star, colour: "#F0E442"), hint: "Y", size: 60)
        ItemView(visual: .shape(kind: .triangle, colour: "#0072B2"), hint: nil, size: 60)
    }
}
