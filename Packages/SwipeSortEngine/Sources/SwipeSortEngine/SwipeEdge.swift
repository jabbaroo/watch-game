/// A screen edge the player can flick an item toward.
public enum SwipeEdge: String, Codable, Sendable, CaseIterable, Hashable, CodingKeyRepresentable {
    case up, down, left, right

    /// Which edges a round uses for a given number of categories.
    public static func edges(forCategoryCount count: Int) -> [SwipeEdge] {
        switch count {
        case ...2: [.left, .right]
        case 3: [.left, .right, .up]
        default: [.left, .right, .up, .down]
        }
    }
}

/// Which category lives at which edge for one round.
public struct EdgeMapping: Codable, Sendable, Equatable {
    public var categoryByEdge: [SwipeEdge: String]

    public init(categoryByEdge: [SwipeEdge: String]) {
        self.categoryByEdge = categoryByEdge
    }

    public func category(at edge: SwipeEdge) -> String? {
        categoryByEdge[edge]
    }

    public func edge(for categoryID: String) -> SwipeEdge? {
        categoryByEdge.first { $0.value == categoryID }?.key
    }

    /// Edges in use, in `SwipeEdge.allCases` order.
    public var edges: [SwipeEdge] {
        SwipeEdge.allCases.filter { categoryByEdge[$0] != nil }
    }
}
