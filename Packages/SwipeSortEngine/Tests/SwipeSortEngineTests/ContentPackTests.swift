import Foundation
import Testing
@testable import SwipeSortEngine

@Suite struct ContentPackTests {
    static let miniJSON = """
    {
      "id": "mini",
      "nameKey": "pack.mini",
      "dimensions": [
        {
          "id": "colour",
          "nameKey": "dimension.colour",
          "values": [
            { "id": "red", "labelKey": "colour.red", "hintKey": "hint.red" },
            { "id": "blue", "labelKey": "colour.blue" }
          ]
        }
      ],
      "items": [
        { "id": "r", "attributes": { "colour": "red" },
          "visual": { "type": "shape", "kind": "circle", "colour": "#D55E00" } },
        { "id": "b", "attributes": { "colour": "blue" },
          "visual": { "type": "image", "assetName": "blue-dot" } }
      ]
    }
    """

    @Test func decodesFromJSON() throws {
        let pack = try JSONDecoder().decode(ContentPack.self, from: Data(Self.miniJSON.utf8))
        #expect(pack.id == "mini")
        #expect(pack.dimensions.count == 1)
        #expect(pack.dimensions[0].values.map(\.id) == ["red", "blue"])
        #expect(pack.dimensions[0].values[0].hintKey == "hint.red")
        #expect(pack.dimensions[0].values[1].hintKey == nil)
        #expect(pack.items[0].visual == .shape(kind: .circle, colour: "#D55E00"))
        #expect(pack.items[1].visual == .image(assetName: "blue-dot"))
        try pack.validate()
    }

    @Test func visualRoundTripsThroughJSON() throws {
        let visuals: [Visual] = [
            .shape(kind: .star, colour: "#0072B2"),
            .shape(kind: .triangle, colour: "#D55E00"),
            .image(assetName: "carrot"),
            .word(textKey: "colour.red", colour: "#D55E00"),
        ]
        for visual in visuals {
            let data = try JSONEncoder().encode(visual)
            let decoded = try JSONDecoder().decode(Visual.self, from: data)
            #expect(decoded == visual)
        }
    }

    @Test func wordVisualAndDescriptionDecodeFromJSON() throws {
        let json = ##"{"type":"word","textKey":"colour.red","colour":"#D55E00"}"##
        #expect(try JSONDecoder().decode(Visual.self, from: Data(json.utf8)) == .word(textKey: "colour.red", colour: "#D55E00"))
        let withoutDescription = try JSONDecoder().decode(ContentPack.self, from: Data(Self.miniJSON.utf8))
        #expect(withoutDescription.descriptionKey == nil)
        let withDescription = Self.miniJSON.replacingOccurrences(of: "\"nameKey\": \"pack.mini\",", with: "\"nameKey\": \"pack.mini\", \"descriptionKey\": \"pack.mini.description\",")
        #expect(try JSONDecoder().decode(ContentPack.self, from: Data(withDescription.utf8)).descriptionKey == "pack.mini.description")
        #expect(ContentPack.shapesAndColours.descriptionKey == "pack.shapes-colours.description")
    }

    @Test func unknownVisualTypeFailsToDecode() {
        let json = #"{"type":"hologram"}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Visual.self, from: Data(json.utf8))
        }
    }

    @Test func builtInShapesPackIsValid() throws {
        let pack = ContentPack.shapesAndColours
        try pack.validate()
        #expect(pack.dimensions.map(\.id) == ["colour", "shape"])
        #expect(pack.dimensions[0].values.count == 4)
        #expect(pack.dimensions[1].values.count == 4)
        #expect(pack.items.count == 16)
    }

    @Test func itemMissingAttributeIsInvalid() {
        var pack = ContentPack.shapesAndColours
        pack.items[0].attributes["shape"] = nil
        #expect(throws: ContentPack.ValidationError.itemMissingAttribute(item: pack.items[0].id, dimension: "shape")) {
            try pack.validate()
        }
    }

    @Test func itemWithUnknownValueIsInvalid() {
        var pack = ContentPack.shapesAndColours
        pack.items[0].attributes["colour"] = "purple"
        #expect(throws: ContentPack.ValidationError.itemUnknownValue(item: pack.items[0].id, dimension: "colour", value: "purple")) {
            try pack.validate()
        }
    }

    @Test func valueWithoutItemsIsInvalid() {
        var pack = ContentPack.shapesAndColours
        pack.dimensions[0].values.append(CategoryValue(id: "purple", labelKey: "colour.purple", hintKey: nil))
        #expect(throws: ContentPack.ValidationError.valueWithoutItems(dimension: "colour", value: "purple")) {
            try pack.validate()
        }
    }

    @Test func dimensionWithOneValueIsInvalid() {
        var pack = ContentPack.shapesAndColours
        pack.dimensions[1].values = [pack.dimensions[1].values[0]]
        #expect(throws: ContentPack.ValidationError.dimensionNeedsTwoValues("shape")) {
            try pack.validate()
        }
    }
}
