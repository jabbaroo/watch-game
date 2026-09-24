public extension ContentPack {
    /// The version 1 pack. Colours are Okabe-Ito values so they stay
    /// distinguishable under red-green colour vision deficiency.
    static let shapesAndColours: ContentPack = {
        let colours: [(id: String, hex: String)] = [
            ("red", "#D55E00"),
            ("yellow", "#F0E442"),
            ("green", "#009E73"),
            ("blue", "#0072B2"),
        ]
        let shapes: [(id: String, kind: ShapeKind)] = [
            ("circle", .circle),
            ("square", .square),
            ("triangle", .triangle),
            ("star", .star),
        ]
        let colourDimension = Dimension(
            id: "colour",
            nameKey: "dimension.colour",
            values: colours.map { CategoryValue(id: $0.id, labelKey: "colour.\($0.id)", hintKey: "hint.colour.\($0.id)") }
        )
        let shapeDimension = Dimension(
            id: "shape",
            nameKey: "dimension.shape",
            values: shapes.map { CategoryValue(id: $0.id, labelKey: "shape.\($0.id)", hintKey: nil) }
        )
        var items: [Item] = []
        for colour in colours {
            for shape in shapes {
                items.append(Item(
                    id: "\(colour.id)-\(shape.id)",
                    attributes: ["colour": colour.id, "shape": shape.id],
                    visual: .shape(kind: shape.kind, colour: colour.hex)
                ))
            }
        }
        return ContentPack(id: "shapes-colours", nameKey: "pack.shapes-colours", dimensions: [colourDimension, shapeDimension], items: items)
    }()
}
