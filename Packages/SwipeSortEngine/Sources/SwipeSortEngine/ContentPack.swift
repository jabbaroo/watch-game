import Foundation

/// A sortable set of items with one or more dimensions to sort them by.
public struct ContentPack: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var nameKey: String
    public var dimensions: [Dimension]
    public var items: [Item]

    public init(id: String, nameKey: String, dimensions: [Dimension], items: [Item]) {
        self.id = id
        self.nameKey = nameKey
        self.dimensions = dimensions
        self.items = items
    }

    public func dimension(id: String) -> Dimension? {
        dimensions.first { $0.id == id }
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case noDimensions
        case noItems
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
/// Version 1 supports code-drawn shapes and asset catalog images only.
public enum Visual: Sendable, Equatable {
    case shape(kind: ShapeKind, colour: String)
    case image(assetName: String)
}

extension Visual: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, kind, colour, assetName
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
        }
    }
}
