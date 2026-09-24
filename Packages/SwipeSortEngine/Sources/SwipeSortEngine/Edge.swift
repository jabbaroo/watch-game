/// A screen edge the player can flick an item toward.
public enum Edge: String, Codable, Sendable, CaseIterable, Hashable, CodingKeyRepresentable {
    case up, down, left, right

    /// Which edges a round uses for a given number of categories.
    public static func edges(forCategoryCount count: Int) -> [Edge] {
        switch count {
        case ...2: [.left, .right]
        case 3: [.left, .right, .up]
        default: [.left, .right, .up, .down]
        }
    }
}

/// Which category lives at which edge for one round.
public struct EdgeMapping: Codable, Sendable, Equatable {
    public var categoryByEdge: [Edge: String]

    public init(categoryByEdge: [Edge: String]) {
        self.categoryByEdge = categoryByEdge
    }

    public func category(at edge: Edge) -> String? {
        categoryByEdge[edge]
    }

    public func edge(for categoryID: String) -> Edge? {
        categoryByEdge.first { $0.value == categoryID }?.key
    }

    /// Edges in use, in `Edge.allCases` order.
    public var edges: [Edge] {
        Edge.allCases.filter { categoryByEdge[$0] != nil }
    }
}
