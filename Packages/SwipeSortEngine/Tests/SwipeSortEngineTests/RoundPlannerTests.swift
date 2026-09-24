import Foundation
import Testing
@testable import SwipeSortEngine

@Suite struct RoundPlannerTests {
    func plans(seed: UInt64 = 1, pack: ContentPack = .shapesAndColours, config: RunConfiguration = .standard) -> [RoundPlan] {
        var rng = SeededGenerator(seed: seed)
        return RoundPlanner.plan(pack: pack, configuration: config, using: &rng)
    }

    @Test func producesOnePlanPerRound() {
        #expect(plans().count == 8)
        #expect(plans().map(\.index) == Array(0..<8))
    }

    @Test func rotatesThroughDimensions() {
        #expect(plans().map(\.dimensionID) == ["colour", "shape", "colour", "shape", "colour", "shape", "colour", "shape"])
    }

    @Test func categoryCountsFollowRamp() {
        #expect(plans().map(\.activeCategoryIDs.count) == [2, 2, 3, 3, 4, 4, 4, 4])
        for plan in plans() {
            #expect(plan.mapping.categoryByEdge.count == plan.activeCategoryIDs.count)
            #expect(Set(plan.mapping.categoryByEdge.values) == Set(plan.activeCategoryIDs))
        }
    }

    @Test func edgeSetsMatchCategoryCount() {
        #expect(SwipeEdge.edges(forCategoryCount: 2) == [.left, .right])
        #expect(SwipeEdge.edges(forCategoryCount: 3) == [.left, .right, .up])
        #expect(SwipeEdge.edges(forCategoryCount: 4) == [.left, .right, .up, .down])
        for plan in plans() {
            #expect(Set(plan.mapping.categoryByEdge.keys) == Set(SwipeEdge.edges(forCategoryCount: plan.activeCategoryIDs.count)))
        }
    }

    @Test func activeCategoriesBelongToDimension() {
        let pack = ContentPack.shapesAndColours
        for plan in plans() {
            let valueIDs = Set(pack.dimension(id: plan.dimensionID)!.values.map(\.id))
            #expect(Set(plan.activeCategoryIDs).isSubset(of: valueIDs))
            #expect(Set(plan.activeCategoryIDs).count == plan.activeCategoryIDs.count)
        }
    }

    @Test func isDeterministicForSeed() {
        #expect(plans(seed: 99) == plans(seed: 99))
        #expect(plans(seed: 99) != plans(seed: 100))
    }

    @Test func everyRoundGetsItsOwnItemSeed() {
        #expect(Set(plans().map(\.itemSeed)).count == 8)
    }

    @Test func capsCategoryCountAtDimensionSize() {
        var pack = ContentPack.shapesAndColours
        pack.dimensions[1].values.removeLast()
        pack.items.removeAll { $0.attributes["shape"] == "star" }
        let result = plans(pack: pack)
        #expect(result[5].dimensionID == "shape")
        #expect(result[5].activeCategoryIDs.count == 3)
        #expect(result[4].activeCategoryIDs.count == 4)
    }

    @Test func categoryCountNeverExceedsTheFourEdges() {
        var pack = ContentPack.shapesAndColours
        pack.dimensions[0].values.append(CategoryValue(id: "purple", labelKey: "colour.purple", hintKey: nil))
        pack.items.append(Item(id: "purple-circle", attributes: ["colour": "purple", "shape": "circle"], visual: .shape(kind: .circle, colour: "#CC79A7")))
        var config = RunConfiguration.standard
        config.categoryRamp = [5]
        let result = plans(pack: pack, config: config)
        for plan in result where plan.dimensionID == "colour" {
            #expect(plan.activeCategoryIDs.count == 4)
            #expect(plan.mapping.categoryByEdge.count == 4)
        }
    }

    @Test func roundPlanDecodesWithoutBackDepth() throws {
        let plan = plans()[0]
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)) as! [String: Any]
        object.removeValue(forKey: "backDepth")
        let decoded = try JSONDecoder().decode(RoundPlan.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.backDepth == 0)
        #expect(decoded.itemSeed == plan.itemSeed)
    }

    @Test func mappingLookupsAreConsistent() {
        let mapping = EdgeMapping(categoryByEdge: [.left: "red", .right: "blue"])
        #expect(mapping.category(at: .left) == "red")
        #expect(mapping.edge(for: "blue") == .right)
        #expect(mapping.category(at: .up) == nil)
        #expect(mapping.edge(for: "green") == nil)
        #expect(mapping.edges == [.left, .right])
    }
}
