/// Produces the stream of items for one round from its own generator, seeded by the
/// plan, so the stream never depends on how many items earlier rounds consumed.
public struct ItemSequencer: Sendable, Equatable {
    private let categories: [String]
    private let candidatesByCategory: [String: [Item]]
    private let maximumConsecutiveSameTarget: Int
    private let holdProbability: Double
    private var generator: SeededGenerator
    private var lastTarget: String?
    private var consecutive = 0

    public init(pack: ContentPack, plan: RoundPlan, maximumConsecutiveSameTarget: Int) {
        generator = SeededGenerator(seed: plan.itemSeed)
        holdProbability = pack.holdProbability
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

    /// The next item, the category it belongs to, and whether it is a hold item that must be
    /// left alone. Picks the target category first, then uniformly among the pack's items with
    /// that value on the active dimension, then draws the hold flag from the pack's probability.
    public mutating func next() -> (item: Item, categoryID: String, hold: Bool) {
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
        let hold = holdProbability > 0 && Double.random(in: 0..<1, using: &generator) < holdProbability
        return (item, target, hold)
    }
}
