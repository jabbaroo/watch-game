/// Produces the stream of items for one round from its own generator, seeded by the
/// plan, so the stream never depends on how many items earlier rounds consumed.
public struct ItemSequencer: Sendable, Equatable {
    private let categories: [String]
    private let candidatesByCategory: [String: [Item]]
    private let maximumConsecutiveSameTarget: Int
    private var generator: SeededGenerator
    private var lastTarget: String?
    private var consecutive = 0

    public init(pack: ContentPack, plan: RoundPlan, maximumConsecutiveSameTarget: Int) {
        generator = SeededGenerator(seed: plan.itemSeed)
        categories = plan.activeCategoryIDs
        var candidates: [String: [Item]] = [:]
        for item in pack.items {
            if let value = item.attributes[plan.dimensionID], plan.activeCategoryIDs.contains(value) {
                candidates[value, default: []].append(item)
            }
        }
        candidatesByCategory = candidates
        self.maximumConsecutiveSameTarget = max(1, maximumConsecutiveSameTarget)
    }

    /// The next item and the category it must be sorted into. Picks the target category
    /// first, then uniformly among the pack's items with that value on the active dimension.
    public mutating func next() -> (item: Item, categoryID: String) {
        var pool = categories
        if let last = lastTarget, consecutive >= maximumConsecutiveSameTarget, categories.count > 1 {
            pool.removeAll { $0 == last }
        }
        guard let target = pool.randomElement(using: &generator),
              let item = candidatesByCategory[target]?.randomElement(using: &generator)
        else {
            preconditionFailure("Pack validation guarantees every active category has items")
        }
        if target == lastTarget {
            consecutive += 1
        } else {
            lastTarget = target
            consecutive = 1
        }
        return (item, target)
    }
}
