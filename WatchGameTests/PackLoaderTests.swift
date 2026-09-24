import Foundation
import Testing
import SwipeSortEngine
import UIKit
@testable import WatchGame

private final class TestBundleMarker {}

@Suite struct PackLoaderTests {
    let testBundle = Bundle(for: TestBundleMarker.self)

    @Test func builtInPackComesFirst() {
        let packs = PackLoader.loadPacks(from: .main)
        #expect(packs.first?.id == ContentPack.shapesAndColours.id)
    }

    @Test func bundledPacksAreValid() throws {
        let packs = try PackLoader.validateBundledPacks(in: .main)
        for pack in packs {
            for item in pack.items {
                if case .image(let assetName) = item.visual {
                    #expect(UIImage(named: assetName) != nil, "missing image asset \(assetName) in pack \(pack.id)")
                }
            }
        }
    }

    @Test func everyBundledPackKeyIsLocalised() throws {
        for pack in try PackLoader.validateBundledPacks(in: .main) {
            var keys = [pack.nameKey]
            if let descriptionKey = pack.descriptionKey { keys.append(descriptionKey) }
            for dimension in pack.dimensions {
                keys.append(dimension.nameKey)
                for value in dimension.values {
                    keys.append(value.labelKey)
                    if let hintKey = value.hintKey { keys.append(hintKey) }
                }
            }
            for item in pack.items {
                if case .word(let textKey, _) = item.visual { keys.append(textKey) }
            }
            for key in keys {
                #expect(Localization.hasString(key), "missing String Catalog entry for \(key) in pack \(pack.id)")
            }
        }
    }

    @Test func goNoGoPackHoldsAQuarterOfItems() throws {
        let pack = try #require(PackLoader.loadPacks(from: .main).first { $0.id == "gonogo" })
        #expect(pack.holdProbability == 0.25)
        #expect(pack.items.count == 16)
        #expect(pack.dimensions.map(\.id) == ["colour", "shape"])
        #expect(ContentPack.shapesAndColours.holdProbability == 0)
    }

    @Test func stroopPackSharesValueIDsAcrossDimensions() throws {
        let stroop = try #require(PackLoader.loadPacks(from: .main).first { $0.id == "stroop" })
        #expect(stroop.items.count == 16)
        #expect(stroop.dimensions.map(\.id) == ["ink", "word"])
        let inkIDs = Set(stroop.dimensions[0].values.map(\.id))
        let wordIDs = Set(stroop.dimensions[1].values.map(\.id))
        #expect(inkIDs == wordIDs, "shared ids let the engine detect congruent items")
        let congruent = stroop.items.filter { Set($0.attributes.values).count == 1 }
        #expect(congruent.count == 4)
        for item in stroop.items {
            guard case .word = item.visual else { Issue.record("Stroop items must be words"); return }
        }
    }

    @Test func loaderSkipsInvalidPacksAndKeepsValidOnes() {
        let packs = PackLoader.loadPacks(from: testBundle)
        #expect(packs.map(\.id) == [ContentPack.shapesAndColours.id, "fixture-valid"])
        #expect(packs[1].items.last?.visual == .image(assetName: "fixture-image"))
    }

    @Test func validateBundledPacksThrowsOnBrokenPack() {
        #expect(throws: (any Error).self) {
            try PackLoader.validateBundledPacks(in: testBundle)
        }
    }
}
