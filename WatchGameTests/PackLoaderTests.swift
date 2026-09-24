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

    @Test func builtInPackKeysAreLocalised() {
        let pack = ContentPack.shapesAndColours
        var keys = [pack.nameKey]
        for dimension in pack.dimensions {
            keys.append(dimension.nameKey)
            for value in dimension.values {
                keys.append(value.labelKey)
                if let hintKey = value.hintKey { keys.append(hintKey) }
            }
        }
        for key in keys {
            #expect(Localization.hasString(key), "missing String Catalog entry for \(key)")
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
