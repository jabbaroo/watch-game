import Testing
@testable import SwipeSortEngine

@Suite struct ItemSequencerTests {
    let pack = ContentPack.shapesAndColours

    func makePlan(categories: [String], dimension: String = "colour", itemSeed: UInt64 = 3) -> RoundPlan {
        let edges = SwipeEdge.edges(forCategoryCount: categories.count)
        return RoundPlan(
            index: 0,
            dimensionID: dimension,
            activeCategoryIDs: categories,
            mapping: EdgeMapping(categoryByEdge: Dictionary(uniqueKeysWithValues: zip(edges, categories))),
            itemSeed: itemSeed
        )
    }

    func drawItems(_ count: Int, plan: RoundPlan, maxRun: Int = 2) -> [(item: Item, categoryID: String, hold: Bool)] {
        var sequencer = ItemSequencer(pack: pack, plan: plan, maximumConsecutiveSameTarget: maxRun)
        return (0..<count).map { _ in sequencer.next() }
    }

    @Test func targetsAreAlwaysActiveCategories() {
        let plan = makePlan(categories: ["red", "blue"])
        for draw in drawItems(200, plan: plan) {
            #expect(["red", "blue"].contains(draw.categoryID))
            #expect(draw.item.attributes["colour"] == draw.categoryID)
        }
    }

    @Test func neverMoreThanTwoOfTheSameTargetInARow() {
        let plan = makePlan(categories: ["red", "yellow", "green", "blue"])
        let targets = drawItems(500, plan: plan).map(\.categoryID)
        var run = 1
        for index in 1..<targets.count {
            run = targets[index] == targets[index - 1] ? run + 1 : 1
            #expect(run <= 2, "run of \(run) at index \(index)")
        }
    }

    @Test func allActiveCategoriesAppear() {
        let plan = makePlan(categories: ["circle", "square", "triangle"], dimension: "shape")
        let targets = Set(drawItems(100, plan: plan).map(\.categoryID))
        #expect(targets == ["circle", "square", "triangle"])
    }

    @Test func inactiveDimensionVaries() {
        let plan = makePlan(categories: ["red", "blue"])
        let shapes = Set(drawItems(100, plan: plan).map { $0.item.attributes["shape"]! })
        #expect(shapes.count == 4)
    }

    @Test func isDeterministicForItemSeed() {
        let a = makePlan(categories: ["red", "blue"], itemSeed: 11)
        let b = makePlan(categories: ["red", "blue"], itemSeed: 12)
        #expect(drawItems(30, plan: a).map(\.item.id) == drawItems(30, plan: a).map(\.item.id))
        #expect(drawItems(30, plan: a).map(\.item.id) != drawItems(30, plan: b).map(\.item.id))
    }

    @Test func holdItemsFollowThePackProbability() {
        var goNoGo = pack
        goNoGo.holdProbability = 0.25
        let plan = makePlan(categories: ["red", "blue"])
        var sequencer = ItemSequencer(pack: goNoGo, plan: plan, maximumConsecutiveSameTarget: 2)
        let holds = (0..<400).filter { _ in sequencer.next().hold }.count
        #expect((60...140).contains(holds), "about a quarter of 400 draws, got \(holds)")
        var plain = ItemSequencer(pack: pack, plan: plan, maximumConsecutiveSameTarget: 2)
        #expect((0..<100).allSatisfy { _ in !plain.next().hold })
    }

    @Test func singleCategoryAllowsRepeats() {
        let plan = makePlan(categories: ["red"])
        let targets = drawItems(10, plan: plan).map(\.categoryID)
        #expect(targets == Array(repeating: "red", count: 10))
    }
}
