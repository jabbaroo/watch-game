import Foundation

/// A sortable set of items with one or more dimensions to sort them by.
public struct ContentPack: Sendable, Equatable, Identifiable {
    public var id: String
    public var nameKey: String
    /// Optional String Catalog key for a one-line description shown in the mode picker.
    public var descriptionKey: String?
    /// Go, no-go: the share of items shown as "hold" items that must be left alone. Zero for plain sorting.
    public var holdProbability: Double
    public var dimensions: [Dimension]
    public var items: [Item]

    public init(id: String, nameKey: String, descriptionKey: String? = nil, holdProbability: Double = 0, dimensions: [Dimension], items: [Item]) {
        self.id = id
        self.nameKey = nameKey
        self.descriptionKey = descriptionKey
        self.holdProbability = holdProbability
        self.dimensions = dimensions
        self.items = items
    }

    public func dimension(id: String) -> Dimension? {
        dimensions.first { $0.id == id }
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case noDimensions
        case noItems
        case invalidHoldProbability(Double)
        case duplicateID(String)
        case dimensionNeedsTwoValues(String)
        case itemMissingAttribute(item: String, dimension: String)
        case itemUnknownValue(item: String, dimension: String, value: String)
        case valueWithoutItems(dimension: String, value: String)
    }

    /// Throws the first structural problem found. A valid pack guarantees every
    /// active category always has at least one item to show.
    public func validate() throws(ValidationError) {
        guard !dimensions.isEmpty else { throw ValidationError.noDimensions }
        guard !items.isEmpty else { throw ValidationError.noItems }
        guard (0...0.9).contains(holdProbability) else { throw ValidationError.invalidHoldProbability(holdProbability) }

        var dimensionIDs = Set<String>()
        for dimension in dimensions {
            guard dimensionIDs.insert(dimension.id).inserted else {
                throw ValidationError.duplicateID(dimension.id)
            }
            guard dimension.values.count >= 2 else {
                throw ValidationError.dimensionNeedsTwoValues(dimension.id)
            }
            var valueIDs = Set<String>()
            for value in dimension.values {
                guard valueIDs.insert(value.id).inserted else {
                    throw ValidationError.duplicateID("\(dimension.id).\(value.id)")
                }
            }
        }

        var itemIDs = Set<String>()
        for item in items {
            guard itemIDs.insert(item.id).inserted else {
                throw ValidationError.duplicateID(item.id)
            }
            for dimension in dimensions {
                guard let value = item.attributes[dimension.id] else {
                    throw ValidationError.itemMissingAttribute(item: item.id, dimension: dimension.id)
                }
                guard dimension.value(id: value) != nil else {
                    throw ValidationError.itemUnknownValue(item: item.id, dimension: dimension.id, value: value)
                }
            }
        }

        for dimension in dimensions {
            for value in dimension.values
            where !items.contains(where: { $0.attributes[dimension.id] == value.id }) {
                throw ValidationError.valueWithoutItems(dimension: dimension.id, value: value.id)
            }
        }
    }
}

extension ContentPack: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, nameKey, descriptionKey, holdProbability, dimensions, items
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        nameKey = try container.decode(String.self, forKey: .nameKey)
        descriptionKey = try container.decodeIfPresent(String.self, forKey: .descriptionKey)
        holdProbability = try container.decodeIfPresent(Double.self, forKey: .holdProbability) ?? 0
        dimensions = try container.decode([Dimension].self, forKey: .dimensions)
        items = try container.decode([Item].self, forKey: .items)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(nameKey, forKey: .nameKey)
        try container.encodeIfPresent(descriptionKey, forKey: .descriptionKey)
        if holdProbability > 0 {
            try container.encode(holdProbability, forKey: .holdProbability)
        }
        try container.encode(dimensions, forKey: .dimensions)
        try container.encode(items, forKey: .items)
    }
}

/// One way of sorting the pack's items, for example colour or shape.
public struct Dimension: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var nameKey: String
    public var values: [CategoryValue]

    public init(id: String, nameKey: String, values: [CategoryValue]) {
        self.id = id
        self.nameKey = nameKey
        self.values = values
    }

    public func value(id: String) -> CategoryValue? {
        values.first { $0.id == id }
    }
}

/// One category within a dimension, for example "red" within colour.
public struct CategoryValue: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var labelKey: String
    /// Optional String Catalog key for a one-character hint shown when the
    /// colour hints setting is on. Nil when the category needs no hint.
    public var hintKey: String?

    public init(id: String, labelKey: String, hintKey: String?) {
        self.id = id
        self.labelKey = labelKey
        self.hintKey = hintKey
    }
}

/// A thing to sort. `attributes` maps dimension id to category value id.
public struct Item: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var attributes: [String: String]
    public var visual: Visual

    public init(id: String, attributes: [String: String], visual: Visual) {
        self.id = id
        self.attributes = attributes
        self.visual = visual
    }
}

public enum ShapeKind: String, Codable, Sendable, CaseIterable {
    case circle, square, triangle, star
}

/// How an item is drawn. Encoded as an object with a `type` discriminator.
public enum Visual: Sendable, Equatable {
    case shape(kind: ShapeKind, colour: String)
    case image(assetName: String)
    /// A localised word drawn in a colour, for Stroop packs. `textKey` is a String Catalog key.
    case word(textKey: String, colour: String)
}

extension Visual: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, kind, colour, assetName, textKey
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "shape":
            self = .shape(
                kind: try container.decode(ShapeKind.self, forKey: .kind),
                colour: try container.decode(String.self, forKey: .colour)
            )
        case "image":
            self = .image(assetName: try container.decode(String.self, forKey: .assetName))
        case "word":
            self = .word(
                textKey: try container.decode(String.self, forKey: .textKey),
                colour: try container.decode(String.self, forKey: .colour)
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container, debugDescription: "Unknown visual type '\(type)'"
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .shape(kind, colour):
            try container.encode("shape", forKey: .type)
            try container.encode(kind, forKey: .kind)
            try container.encode(colour, forKey: .colour)
        case let .image(assetName):
            try container.encode("image", forKey: .type)
            try container.encode(assetName, forKey: .assetName)
        case let .word(textKey, colour):
            try container.encode("word", forKey: .type)
            try container.encode(textKey, forKey: .textKey)
            try container.encode(colour, forKey: .colour)
        }
    }
}
