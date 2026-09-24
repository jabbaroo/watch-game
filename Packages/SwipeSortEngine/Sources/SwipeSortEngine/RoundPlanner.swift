public struct RoundPlan: Codable, Sendable, Equatable {
    public var index: Int
    public var dimensionID: String
    public var activeCategoryIDs: [String]
    public var mapping: EdgeMapping
    /// Seed for this round's item stream. Drawn during planning so the items a
    /// round shows never depend on how many items earlier rounds consumed.
    public var itemSeed: UInt64

    public init(index: Int, dimensionID: String, activeCategoryIDs: [String], mapping: EdgeMapping, itemSeed: UInt64) {
        self.index = index
        self.dimensionID = dimensionID
        self.activeCategoryIDs = activeCategoryIDs
        self.mapping = mapping
        self.itemSeed = itemSeed
    }
}

public enum RoundPlanner {
    /// Builds every round of a run up front so the whole run is determined by the seed.
    public static func plan(pack: ContentPack, configuration: RunConfiguration, using rng: inout SeededGenerator) -> [RoundPlan] {
        precondition(!pack.dimensions.isEmpty, "A pack needs at least one dimension")
        return (0..<configuration.roundCount).map { index in
            let dimension = pack.dimensions[index % pack.dimensions.count]
            let count = min(configuration.categoryCount(roundIndex: index), dimension.values.count)
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
                itemSeed: rng.next()
            )
        }
    }
}
