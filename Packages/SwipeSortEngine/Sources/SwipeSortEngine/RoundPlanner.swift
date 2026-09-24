public struct RoundPlan: Sendable, Equatable {
    public var index: Int
    public var dimensionID: String
    public var activeCategoryIDs: [String]
    public var mapping: EdgeMapping
    /// Seed for this round's item stream. Drawn during planning so the items a
    /// round shows never depend on how many items earlier rounds consumed.
    public var itemSeed: UInt64
    /// N-back depth for the round: 0 sorts the item on screen, n sorts the item shown n steps earlier.
    public var backDepth: Int

    public init(index: Int, dimensionID: String, activeCategoryIDs: [String], mapping: EdgeMapping, itemSeed: UInt64, backDepth: Int = 0) {
        self.index = index
        self.dimensionID = dimensionID
        self.activeCategoryIDs = activeCategoryIDs
        self.mapping = mapping
        self.itemSeed = itemSeed
        self.backDepth = backDepth
    }
}

extension RoundPlan: Codable {
    private enum CodingKeys: String, CodingKey {
        case index, dimensionID, activeCategoryIDs, mapping, itemSeed, backDepth
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        index = try c.decode(Int.self, forKey: .index)
        dimensionID = try c.decode(String.self, forKey: .dimensionID)
        activeCategoryIDs = try c.decode([String].self, forKey: .activeCategoryIDs)
        mapping = try c.decode(EdgeMapping.self, forKey: .mapping)
        itemSeed = try c.decode(UInt64.self, forKey: .itemSeed)
        backDepth = try c.decodeIfPresent(Int.self, forKey: .backDepth) ?? 0
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(index, forKey: .index)
        try c.encode(dimensionID, forKey: .dimensionID)
        try c.encode(activeCategoryIDs, forKey: .activeCategoryIDs)
        try c.encode(mapping, forKey: .mapping)
        try c.encode(itemSeed, forKey: .itemSeed)
        try c.encode(backDepth, forKey: .backDepth)
    }
}

public enum RoundPlanner {
    /// Builds every round of a run up front so the whole run is determined by the seed.
    public static func plan(pack: ContentPack, configuration: RunConfiguration, using rng: inout SeededGenerator) -> [RoundPlan] {
        precondition(!pack.dimensions.isEmpty, "A pack needs at least one dimension")
        return (0..<configuration.roundCount).map { index in
            let dimension = pack.dimensions[index % pack.dimensions.count]
            let count = min(configuration.categoryCount(roundIndex: index), dimension.values.count, SwipeEdge.allCases.count)
            let active = Array(dimension.values.map(\.id).shuffled(using: &rng).prefix(count))
            let edges = SwipeEdge.edges(forCategoryCount: count).shuffled(using: &rng)
            var categoryByEdge: [SwipeEdge: String] = [:]
            for (edge, category) in zip(edges, active) {
                categoryByEdge[edge] = category
            }
            return RoundPlan(
                index: index,
                dimensionID: dimension.id,
                activeCategoryIDs: active,
                mapping: EdgeMapping(categoryByEdge: categoryByEdge),
                itemSeed: rng.next(),
                backDepth: pack.backDepth(roundIndex: index)
            )
        }
    }
}
