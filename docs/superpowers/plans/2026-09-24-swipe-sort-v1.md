# Swipe Sort v1 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the version 1 Swipe Sort watchOS game described in `docs/superpowers/specs/2026-09-24-swipe-sort-design.md`: a standalone, paid, App Store ready Apple Watch sorting game with a deterministic engine, haptic-first feedback, local history and a Smart Stack widget.

**Architecture:** A pure Swift package `SwipeSortEngine` holds all game rules as `Sendable` value types driven by explicit events and a caller-supplied clock, tested on macOS with `swift test`. A watchOS app target `WatchGame` wraps the engine in an `@Observable` session, SwiftUI views, feedback services and SwiftData persistence. An iOS container target exists only because Apple's watch-only app packaging requires it.

**Tech Stack:** Xcode 27.0, Swift 6.4 in Swift 6 language mode with approachable concurrency and main-actor default isolation for the app target, SwiftUI, Observation, SwiftData, Swift Charts, WidgetKit, AVFoundation, WatchKit haptics, Swift Testing. Minimum deployment watchOS 26.0. No third-party dependencies.

---

## Conventions for every task

- The active developer directory on this Mac is the Command Line Tools, so every `xcodebuild`, `xcrun` and `swift` command must run with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` exported. The scripts in `Scripts/` do this for you; use them.
- Commit after every task with a conventional-commit message. Never commit build products.
- Tests use Swift Testing (`import Testing`, `@Test`, `#expect`), never XCTest, except the UI test bundle in Task 23 which must be XCTest.
- All engine types are value types and `Sendable`. The engine never reads a clock: every event is applied `at now: Duration` where `now` is time elapsed since the session's epoch.
- Round indices are zero-based in code and one-based in the UI.
- Colours in packs are hex strings like `#D55E00`.
- Do not add features that are not in the spec. If a spec detail is missing, choose the simplest behaviour and note it in the commit message.

## File structure

```
WatchGame/                                    repo root
├── Scripts/
│   ├── engine-test.sh                        swift test for the engine package
│   ├── build.sh                              xcodebuild the watch app for the simulator
│   └── test.sh                               xcodebuild test on a watch simulator
├── Packages/SwipeSortEngine/
│   ├── Package.swift
│   ├── Sources/SwipeSortEngine/
│   │   ├── SeededGenerator.swift             deterministic RNG
│   │   ├── ContentPack.swift                 pack model, Codable, validation
│   │   ├── BuiltInPacks.swift                ContentPack.shapesAndColours
│   │   ├── RunConfiguration.swift            tunables and window schedule
│   │   ├── ScoringRules.swift                points and multipliers
│   │   ├── Edge.swift                        Edge and EdgeMapping
│   │   ├── RoundPlanner.swift                RoundPlan and planner
│   │   ├── ItemSequencer.swift               item stream for a round
│   │   ├── Results.swift                     ItemResult, RoundResult, RunSummary
│   │   ├── RunEvents.swift                   RunEvent, RunEffect, FeedbackCue, RunPhase, ActiveItem
│   │   ├── RunState.swift                    the state machine
│   │   ├── RunStatistics.swift               results breakdown
│   │   └── DailySeed.swift                   date to seed
│   └── Tests/SwipeSortEngineTests/           tests grouped by behaviour, plus RunHarness.swift
├── WatchGame.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/WatchGame.xcscheme
├── WatchGame/                                watch app target sources (synchronized folder)
│   ├── WatchGameApp.swift                    @main, model container, root view
│   ├── AppEnvironment.swift                  builds services and store once
│   ├── Game/GameSession.swift                @Observable driver for RunState
│   ├── Game/Localization.swift               key to localised string helpers
│   ├── Feedback/FeedbackCue+Haptics.swift    HapticsService protocol and WatchKit implementation
│   ├── Feedback/SoundService.swift           AVAudioEngine implementation
│   ├── Persistence/HistoryModels.swift       RunEntry, RoundEntry, ItemEntry (SwiftData)
│   ├── Persistence/HistoryStore.swift        inserts and queries
│   ├── Persistence/HistorySummary.swift      aggregate stats for History screen
│   ├── Packs/PackLoader.swift                bundled pack loading with fallback
│   ├── Views/Home/HomeView.swift
│   ├── Views/Play/PlayView.swift
│   ├── Views/Play/ItemView.swift             draws a Visual
│   ├── Views/Play/EdgeLabelsView.swift
│   ├── Views/Play/SwipeClassifier.swift      gesture maths, pure and testable
│   ├── Views/Play/PausedView.swift
│   ├── Views/Play/RoundIntroView.swift
│   ├── Views/Play/ConfettiView.swift
│   ├── Views/Results/ResultsView.swift
│   ├── Views/History/HistoryView.swift
│   ├── Views/Settings/SettingsView.swift
│   ├── Views/Settings/AppSettings.swift      @AppStorage keys
│   ├── Resources/Packs/shapes-colours.json
│   ├── Resources/Sounds/*.wav                generated by Tools/generate_sounds.py
│   ├── Localizable.xcstrings
│   ├── Assets.xcassets/
│   └── PrivacyInfo.xcprivacy
├── WatchGameTests/                           watch unit tests (synchronized folder)
├── WatchGameUITests/                         XCTest UI smoke test (Task 23)
├── WatchGameWidget/                          widget extension (Task 22)
├── Tools/generate_sounds.py
└── docs/
```

---

## Chunk 1: Engine foundations

### Task 1: Engine package skeleton, scripts, seeded generator

**Files:**
- Create: `Packages/SwipeSortEngine/Package.swift`
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/SeededGenerator.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/SeededGeneratorTests.swift`
- Create: `Scripts/engine-test.sh`

- [ ] **Step 1: Create the package manifest**

`Packages/SwipeSortEngine/Package.swift`:

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwipeSortEngine",
    platforms: [.watchOS("26.0"), .macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "SwipeSortEngine", targets: ["SwipeSortEngine"]),
    ],
    targets: [
        .target(name: "SwipeSortEngine"),
        .testTarget(name: "SwipeSortEngineTests", dependencies: ["SwipeSortEngine"]),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Create the engine test script**

`Scripts/engine-test.sh`:

```bash
#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
swift test --package-path Packages/SwipeSortEngine "$@"
```

Run `chmod +x Scripts/engine-test.sh`.

- [ ] **Step 3: Write the failing test**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/SeededGeneratorTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct SeededGeneratorTests {
    @Test func sameSeedProducesSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let first = (0..<8).map { _ in a.next() }
        let second = (0..<8).map { _ in b.next() }
        #expect(first == second)
    }

    @Test func differentSeedsProduceDifferentSequences() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test func shuffleIsDeterministic() {
        var a = SeededGenerator(seed: 7)
        var b = SeededGenerator(seed: 7)
        let items = Array(1...10)
        #expect(items.shuffled(using: &a) == items.shuffled(using: &b))
    }
}
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `Scripts/engine-test.sh`
Expected: SwiftPM fails before compiling anything with `target 'SwipeSortEngine' referenced in product 'SwipeSortEngine' is empty`, because the source folder has no files yet.

- [ ] **Step 5: Implement the generator (SplitMix64)**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/SeededGenerator.swift`:

```swift
/// Deterministic random number generator (SplitMix64).
/// The same seed always yields the same sequence on every platform.
public struct SeededGenerator: RandomNumberGenerator, Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: a line like `Test run with 3 tests in 1 suite passed`.

- [ ] **Step 7: Commit**

```bash
git add Packages Scripts
git commit -m "feat(engine): add SwipeSortEngine package with seeded generator"
```

### Task 2: Content pack model, decoding and validation

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/ContentPack.swift`
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/BuiltInPacks.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ContentPackTests.swift`

- [ ] **Step 1: Write the failing tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ContentPackTests.swift`:

```swift
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
        ]
        for visual in visuals {
            let data = try JSONEncoder().encode(visual)
            let decoded = try JSONDecoder().decode(Visual.self, from: data)
            #expect(decoded == visual)
        }
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/engine-test.sh`
Expected: compile errors about `ContentPack`, `Visual`, `CategoryValue`.

- [ ] **Step 3: Implement the model**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/ContentPack.swift`:

```swift
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
```

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/BuiltInPacks.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all ContentPack tests pass (8 tests) plus the 3 generator tests.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): content pack model, JSON coding, validation and built-in shapes pack"
```

### Task 3: Run configuration and scoring rules

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunConfiguration.swift`
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/ScoringRules.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunConfigurationTests.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ScoringRulesTests.swift`

- [ ] **Step 1: Write the failing tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunConfigurationTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct RunConfigurationTests {
    let config = RunConfiguration.standard

    @Test func standardValuesMatchSpec() {
        #expect(config.roundCount == 8)
        #expect(config.roundDuration == .seconds(45))
        #expect(config.startingLives == 3)
        #expect(config.maximumLives == 3)
        #expect(config.categoryRamp == [2, 2, 3, 3, 4, 4, 4, 4])
    }

    @Test func windowFallsPerRound() {
        #expect(config.itemWindow(roundIndex: 0, streak: 0) == .seconds(2))
        #expect(config.itemWindow(roundIndex: 1, streak: 0) == .milliseconds(1850))
        #expect(config.itemWindow(roundIndex: 7, streak: 0) == .milliseconds(950))
    }

    @Test func windowTrimsEveryFiveStreakUpToCap() {
        #expect(config.itemWindow(roundIndex: 0, streak: 4) == .seconds(2))
        #expect(config.itemWindow(roundIndex: 0, streak: 5) == .milliseconds(1950))
        #expect(config.itemWindow(roundIndex: 0, streak: 10) == .milliseconds(1900))
        #expect(config.itemWindow(roundIndex: 0, streak: 30) == .milliseconds(1700))
        #expect(config.itemWindow(roundIndex: 0, streak: 100) == .milliseconds(1700))
    }

    @Test func windowNeverDropsBelowFloor() {
        #expect(config.itemWindow(roundIndex: 7, streak: 30) == .milliseconds(800))
        #expect(config.itemWindow(roundIndex: 20, streak: 0) == .milliseconds(800))
    }

    @Test func categoryCountFollowsRampAndRepeatsLastValue() {
        #expect((0..<8).map { config.categoryCount(roundIndex: $0) } == [2, 2, 3, 3, 4, 4, 4, 4])
        #expect(config.categoryCount(roundIndex: 12) == 4)
    }

    @Test func streakKnobsAgree() {
        // Spec 3.4: window trim, milestone haptic and multiplier all align on the same streak step.
        #expect(config.streakStep == 5)
        #expect(config.scoring.multiplierStep == config.streakStep)
    }
}
```

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ScoringRulesTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct ScoringRulesTests {
    let rules = ScoringRules()

    @Test func multiplierTable() {
        let expected: [(Int, Int)] = [(1, 1), (4, 1), (5, 2), (9, 2), (10, 3), (14, 3), (15, 4), (100, 4)]
        for (streak, multiplier) in expected {
            #expect(rules.multiplier(streak: streak) == multiplier, "streak \(streak)")
        }
    }

    @Test func speedBonusScalesWithRemainingWindow() {
        #expect(rules.speedBonus(reaction: .zero, window: .seconds(2)) == 50)
        #expect(rules.speedBonus(reaction: .seconds(1), window: .seconds(2)) == 25)
        #expect(rules.speedBonus(reaction: .seconds(2), window: .seconds(2)) == 0)
        #expect(rules.speedBonus(reaction: .seconds(3), window: .seconds(2)) == 0)
    }

    @Test func pointsCombineBaseMultiplierAndBonus() {
        #expect(rules.points(streak: 1, reaction: .seconds(1), window: .seconds(2)) == 125)
        #expect(rules.points(streak: 6, reaction: .seconds(1), window: .seconds(2)) == 225)
        #expect(rules.points(streak: 16, reaction: .zero, window: .seconds(2)) == 450)
    }

    @Test func perfectRoundBonusIsFiveHundred() {
        #expect(rules.perfectRoundBonus == 500)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/engine-test.sh`
Expected: compile errors for `RunConfiguration` and `ScoringRules`.

- [ ] **Step 3: Implement configuration and scoring**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunConfiguration.swift`:

```swift
/// Every tunable number in the game. Change values here, not in the engine.
public struct RunConfiguration: Sendable, Equatable {
    public var roundCount = 8
    public var roundDuration: Duration = .seconds(45)
    public var interItemDelay: Duration = .milliseconds(250)

    public var initialWindow: Duration = .seconds(2)
    public var windowDecrementPerRound: Duration = .milliseconds(150)
    /// Every `streakStep` consecutive correct answers is a milestone: the window trims,
    /// the milestone haptic fires and (through `ScoringRules.multiplierStep`) the multiplier steps up.
    public var streakStep = 5
    public var streakTrimStep: Duration = .milliseconds(50)
    public var maximumStreakTrim: Duration = .milliseconds(300)
    public var minimumWindow: Duration = .milliseconds(800)

    public var startingLives = 3
    public var maximumLives = 3
    public var categoryRamp = [2, 2, 3, 3, 4, 4, 4, 4]
    public var maximumConsecutiveSameTarget = 2
    public var scoring = ScoringRules()

    public init() {}

    public static let standard = RunConfiguration()

    /// The time an item stays on screen. `roundIndex` is zero-based and
    /// `streak` is the number of consecutive correct answers so far this round.
    public func itemWindow(roundIndex: Int, streak: Int) -> Duration {
        let base = initialWindow - windowDecrementPerRound * roundIndex
        let trimSteps = streakStep > 0 ? streak / streakStep : 0
        let trim = min(streakTrimStep * trimSteps, maximumStreakTrim)
        return max(base - trim, minimumWindow)
    }

    public func categoryCount(roundIndex: Int) -> Int {
        if categoryRamp.indices.contains(roundIndex) {
            return categoryRamp[roundIndex]
        }
        return categoryRamp.last ?? 2
    }
}
```

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/ScoringRules.swift`:

```swift
public struct ScoringRules: Sendable, Equatable {
    public var basePoints = 100
    public var multiplierStep = 5
    public var maximumMultiplier = 4
    public var speedBonusMaximum = 50
    public var perfectRoundBonus = 500

    public init() {}

    /// Streak counts the current correct answer, so the first answer is streak 1.
    /// The multiplier steps up on every multiple of `multiplierStep`, so the fifth
    /// consecutive correct answer is the first to score double.
    public func multiplier(streak: Int) -> Int {
        guard streak >= 1 else { return 1 }
        return min(maximumMultiplier, 1 + streak / multiplierStep)
    }

    public func speedBonus(reaction: Duration, window: Duration) -> Int {
        guard window > .zero else { return 0 }
        let remaining = max(window - reaction, .zero)
        let fraction = remaining / window
        return Int((Double(speedBonusMaximum) * fraction).rounded())
    }

    public func points(streak: Int, reaction: Duration, window: Duration) -> Int {
        basePoints * multiplier(streak: streak) + speedBonus(reaction: reaction, window: window)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): run configuration with window schedule and scoring rules"
```

### Task 4: Edges, edge mapping and round planner

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/Edge.swift`
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/RoundPlanner.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RoundPlannerTests.swift`

- [ ] **Step 1: Write the failing tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RoundPlannerTests.swift`:

```swift
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
        #expect(Edge.edges(forCategoryCount: 2) == [.left, .right])
        #expect(Edge.edges(forCategoryCount: 3) == [.left, .right, .up])
        #expect(Edge.edges(forCategoryCount: 4) == [.left, .right, .up, .down])
        for plan in plans() {
            #expect(Set(plan.mapping.categoryByEdge.keys) == Set(Edge.edges(forCategoryCount: plan.activeCategoryIDs.count)))
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

    @Test func mappingLookupsAreConsistent() {
        let mapping = EdgeMapping(categoryByEdge: [.left: "red", .right: "blue"])
        #expect(mapping.category(at: .left) == "red")
        #expect(mapping.edge(for: "blue") == .right)
        #expect(mapping.category(at: .up) == nil)
        #expect(mapping.edge(for: "green") == nil)
        #expect(mapping.edges == [.left, .right])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/engine-test.sh`
Expected: compile errors for `Edge`, `EdgeMapping`, `RoundPlan`, `RoundPlanner`.

- [ ] **Step 3: Implement edges and the planner**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/Edge.swift`:

```swift
/// A screen edge the player can flick an item toward.
public enum Edge: String, Codable, Sendable, CaseIterable, Hashable, CodingKeyRepresentable {
    case up, down, left, right

    /// Which edges a round uses for a given number of categories.
    public static func edges(forCategoryCount count: Int) -> [Edge] {
        switch count {
        case ...2: [.left, .right]
        case 3: [.left, .right, .up]
        default: [.left, .right, .up, .down]
        }
    }
}

/// Which category lives at which edge for one round.
public struct EdgeMapping: Codable, Sendable, Equatable {
    public var categoryByEdge: [Edge: String]

    public init(categoryByEdge: [Edge: String]) {
        self.categoryByEdge = categoryByEdge
    }

    public func category(at edge: Edge) -> String? {
        categoryByEdge[edge]
    }

    public func edge(for categoryID: String) -> Edge? {
        categoryByEdge.first { $0.value == categoryID }?.key
    }

    /// Edges in use, in `Edge.allCases` order.
    public var edges: [Edge] {
        Edge.allCases.filter { categoryByEdge[$0] != nil }
    }
}
```

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/RoundPlanner.swift`:

```swift
public struct RoundPlan: Codable, Sendable, Equatable {
    public var index: Int
    public var dimensionID: String
    public var activeCategoryIDs: [String]
    public var mapping: EdgeMapping
    /// Seed for this round's item stream. Drawn during planning so the items a
    /// round shows never depend on how many items earlier rounds consumed.
    public var itemSeed: UInt64

    public init(index: Int, dimensionID: String, activeCategoryIDs: [String], mapping: EdgeMapping, itemSeed: UInt64) {
        self.index = index
        self.dimensionID = dimensionID
        self.activeCategoryIDs = activeCategoryIDs
        self.mapping = mapping
        self.itemSeed = itemSeed
    }
}

public enum RoundPlanner {
    /// Builds every round of a run up front so the whole run is determined by the seed.
    public static func plan(pack: ContentPack, configuration: RunConfiguration, using rng: inout SeededGenerator) -> [RoundPlan] {
        precondition(!pack.dimensions.isEmpty, "A pack needs at least one dimension")
        return (0..<configuration.roundCount).map { index in
            let dimension = pack.dimensions[index % pack.dimensions.count]
            let count = min(configuration.categoryCount(roundIndex: index), dimension.values.count)
            let active = Array(dimension.values.map(\.id).shuffled(using: &rng).prefix(count))
            let edges = Edge.edges(forCategoryCount: count).shuffled(using: &rng)
            var categoryByEdge: [Edge: String] = [:]
            for (edge, category) in zip(edges, active) {
                categoryByEdge[edge] = category
            }
            return RoundPlan(
                index: index,
                dimensionID: dimension.id,
                activeCategoryIDs: active,
                mapping: EdgeMapping(categoryByEdge: categoryByEdge),
                itemSeed: rng.next()
            )
        }
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): edges, edge mapping and deterministic round planner"
```

### Task 5: Item sequencer

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/ItemSequencer.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ItemSequencerTests.swift`

- [ ] **Step 1: Write the failing tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ItemSequencerTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct ItemSequencerTests {
    let pack = ContentPack.shapesAndColours

    func makePlan(categories: [String], dimension: String = "colour", itemSeed: UInt64 = 3) -> RoundPlan {
        let edges = Edge.edges(forCategoryCount: categories.count)
        return RoundPlan(
            index: 0,
            dimensionID: dimension,
            activeCategoryIDs: categories,
            mapping: EdgeMapping(categoryByEdge: Dictionary(uniqueKeysWithValues: zip(edges, categories))),
            itemSeed: itemSeed
        )
    }

    func drawItems(_ count: Int, plan: RoundPlan, maxRun: Int = 2) -> [(item: Item, categoryID: String)] {
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

    @Test func singleCategoryAllowsRepeats() {
        let plan = makePlan(categories: ["red"])
        let targets = drawItems(10, plan: plan).map(\.categoryID)
        #expect(targets == Array(repeating: "red", count: 10))
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/engine-test.sh`
Expected: compile error for `ItemSequencer`.

- [ ] **Step 3: Implement the sequencer**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/ItemSequencer.swift`:

```swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): self-seeded item sequencer with anti-run rule"
```

## Chunk 2: Engine state machine

### Task 6: Result types, events, effects and phases

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/Results.swift`
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunEvents.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ResultsTests.swift`

- [ ] **Step 1: Write the failing test**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/ResultsTests.swift`:

```swift
import Foundation
import Testing
@testable import SwipeSortEngine

@Suite struct ResultsTests {
    func round(index: Int, cutShort: Bool) -> RoundResult {
        RoundResult(index: index, dimensionID: "colour", categoryCount: 2, perfect: false, cutShort: cutShort, score: 0, items: [])
    }

    @Test func roundsCompletedIgnoresCutShortRounds() {
        let summary = RunSummary(seed: 1, packID: "p", score: 0, livesRemaining: 0, endReason: .outOfLives,
                                 rounds: [round(index: 0, cutShort: false), round(index: 1, cutShort: true)])
        #expect(summary.roundsCompleted == 1)
    }

    @Test func completedOnlyForNaturalEndings() {
        for reason in [RunEndReason.completedAllRounds, .outOfLives] {
            let summary = RunSummary(seed: 1, packID: "p", score: 0, livesRemaining: 0, endReason: reason, rounds: [])
            #expect(summary.completed)
        }
        for reason in [RunEndReason.quit, .abandoned] {
            let summary = RunSummary(seed: 1, packID: "p", score: 0, livesRemaining: 0, endReason: reason, rounds: [])
            #expect(!summary.completed)
        }
    }

    @Test func resultsRoundTripThroughJSON() throws {
        let item = ItemResult(roundIndex: 0, itemIndex: 3, dimensionID: "colour", attributes: ["colour": "red", "shape": "star"],
                              expectedCategoryID: "red", answeredCategoryID: "blue", correct: false, timedOut: false,
                              reaction: .milliseconds(420), window: .seconds(2), points: 0)
        let round = RoundResult(index: 0, dimensionID: "colour", categoryCount: 2, perfect: false, cutShort: false, score: 0, items: [item])
        let summary = RunSummary(seed: 99, packID: "p", score: 0, livesRemaining: 2, endReason: .completedAllRounds, rounds: [round])
        let data = try JSONEncoder().encode(summary)
        #expect(try JSONDecoder().decode(RunSummary.self, from: data) == summary)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/engine-test.sh`
Expected: compile errors for `RoundResult`, `RunSummary`, `ItemResult`.

- [ ] **Step 3: Implement the result and event types**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/Results.swift`:

```swift
/// One resolved item. Produced by the engine, persisted by the app.
public struct ItemResult: Codable, Sendable, Equatable {
    public var roundIndex: Int
    public var itemIndex: Int
    public var dimensionID: String
    public var attributes: [String: String]
    public var expectedCategoryID: String
    /// Nil for a timeout.
    public var answeredCategoryID: String?
    public var correct: Bool
    public var timedOut: Bool
    /// Nil for a timeout.
    public var reaction: Duration?
    public var window: Duration
    public var points: Int

    public init(roundIndex: Int, itemIndex: Int, dimensionID: String, attributes: [String: String],
                expectedCategoryID: String, answeredCategoryID: String?, correct: Bool, timedOut: Bool,
                reaction: Duration?, window: Duration, points: Int) {
        self.roundIndex = roundIndex
        self.itemIndex = itemIndex
        self.dimensionID = dimensionID
        self.attributes = attributes
        self.expectedCategoryID = expectedCategoryID
        self.answeredCategoryID = answeredCategoryID
        self.correct = correct
        self.timedOut = timedOut
        self.reaction = reaction
        self.window = window
        self.points = points
    }
}

/// One finished round, including one cut short by running out of lives.
public struct RoundResult: Codable, Sendable, Equatable {
    public var index: Int
    public var dimensionID: String
    public var categoryCount: Int
    public var perfect: Bool
    public var cutShort: Bool
    /// Item points plus any perfect-round bonus.
    public var score: Int
    public var items: [ItemResult]

    public init(index: Int, dimensionID: String, categoryCount: Int, perfect: Bool, cutShort: Bool, score: Int, items: [ItemResult]) {
        self.index = index
        self.dimensionID = dimensionID
        self.categoryCount = categoryCount
        self.perfect = perfect
        self.cutShort = cutShort
        self.score = score
        self.items = items
    }
}

public enum RunEndReason: String, Codable, Sendable {
    case completedAllRounds
    case outOfLives
    case quit
    /// Set by the app for a run interrupted by a process kill. The engine never produces it.
    case abandoned
}

/// Everything the engine knows about a finished run.
public struct RunSummary: Codable, Sendable, Equatable {
    public var seed: UInt64
    public var packID: String
    public var score: Int
    public var livesRemaining: Int
    public var endReason: RunEndReason
    public var rounds: [RoundResult]

    public init(seed: UInt64, packID: String, score: Int, livesRemaining: Int, endReason: RunEndReason, rounds: [RoundResult]) {
        self.seed = seed
        self.packID = packID
        self.score = score
        self.livesRemaining = livesRemaining
        self.endReason = endReason
        self.rounds = rounds
    }

    /// A run counts as complete only when it ended naturally.
    public var completed: Bool { endReason == .completedAllRounds || endReason == .outOfLives }

    /// Rounds that ran to the clock.
    public var roundsCompleted: Int { rounds.filter { !$0.cutShort }.count }
}
```

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunEvents.swift`:

```swift
/// The item currently on screen.
public struct ActiveItem: Sendable, Equatable {
    public var index: Int
    public var item: Item
    public var expectedCategoryID: String
    public var expectedEdge: Edge
    public var shownAt: Duration
    public var deadline: Duration
    public var window: Duration

    public init(index: Int, item: Item, expectedCategoryID: String, expectedEdge: Edge, shownAt: Duration, deadline: Duration, window: Duration) {
        self.index = index
        self.item = item
        self.expectedCategoryID = expectedCategoryID
        self.expectedEdge = expectedEdge
        self.shownAt = shownAt
        self.deadline = deadline
        self.window = window
    }
}

public enum ItemOutcome: Sendable, Equatable {
    case correct(points: Int, streak: Int)
    case wrong
    case timedOut
}

/// The engine says when feedback happens; the app's services decide what it feels and sounds like.
public enum FeedbackCue: Sendable, Equatable {
    case correct(streak: Int)
    case streakMilestone(streak: Int)
    case wrong
    case timedOut
    case lifeEarned
    case roundStarted
    case perfectRound
    case runEnded
}

public enum RunEvent: Sendable, Equatable {
    case startRun
    case startRound
    case answer(Edge)
    /// "Time may have passed." Handles timeouts, the inter-item gap and the round clock.
    case tick
    case pause
    case resume
    case quit
}

public indirect enum RunPhase: Sendable, Equatable {
    case notStarted
    case roundIntro(RoundPlan)
    case playing(ActiveItem)
    case betweenItems(nextItemAt: Duration)
    case paused(resuming: RunPhase, pausedAt: Duration)
    case finished(RunSummary)
}

public enum RunEffect: Sendable, Equatable {
    case roundIntro(RoundPlan)
    case roundStarted(RoundPlan)
    /// Also emitted on resume with shifted times. Views key entrance animations on `ActiveItem.index`.
    case itemShown(ActiveItem)
    case itemResolved(ItemResult, ItemOutcome)
    case livesChanged(Int)
    case scoreChanged(Int)
    case roundEnded(RoundResult)
    case runEnded(RunSummary)
    case feedback(FeedbackCue)
    /// The driver must send `.tick` no later than this time.
    case wake(at: Duration)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): result, event, effect and phase types"
```

### Task 7: RunState core (start, items, answers, timeouts, lives, round clock, run end)

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunState.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunHarness.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunStateTests.swift`

- [ ] **Step 1: Write the test harness and the failing tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunHarness.swift`:

```swift
@testable import SwipeSortEngine

/// Drives a RunState with an explicit clock so tests read like a script.
struct RunHarness {
    var state: RunState
    var now: Duration = .zero
    var effects: [RunEffect] = []

    init(seed: UInt64 = 1, configuration: RunConfiguration = .standard, pack: ContentPack = .shapesAndColours) {
        state = RunState(pack: pack, configuration: configuration, seed: seed)
    }

    @discardableResult
    mutating func send(_ event: RunEvent, after delay: Duration = .zero) -> [RunEffect] {
        now += delay
        let produced = state.apply(event, at: now)
        effects += produced
        return produced
    }

    var activeItem: ActiveItem? {
        if case .playing(let active) = state.phase { return active }
        return nil
    }

    mutating func startRunAndRound() {
        send(.startRun)
        send(.startRound)
    }

    /// Answers the current item correctly after `reaction`, then ticks through the gap so the next item is showing.
    mutating func answerCorrectly(reaction: Duration = .milliseconds(500)) {
        guard let active = activeItem else { preconditionFailure("No active item") }
        send(.answer(active.expectedEdge), after: reaction)
        advanceToNextItem()
    }

    /// Answers with a mapped edge that is not the expected one.
    mutating func answerWrong(reaction: Duration = .milliseconds(500)) {
        guard let active = activeItem else { preconditionFailure("No active item") }
        let wrongEdge = state.currentPlan.mapping.edges.first { $0 != active.expectedEdge }!
        send(.answer(wrongEdge), after: reaction)
        advanceToNextItem()
    }

    mutating func advanceToNextItem() {
        if case .betweenItems(let nextItemAt) = state.phase {
            send(.tick, after: nextItemAt - now)
        }
    }

    /// Lets the round clock run out.
    @discardableResult
    mutating func finishRoundByClock() -> [RunEffect] {
        let remaining = state.roundTimeRemaining(at: now)
        return send(.tick, after: remaining)
    }

    func contains(_ cue: FeedbackCue, in produced: [RunEffect]) -> Bool {
        produced.contains(.feedback(cue))
    }
}
```

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunStateTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct RunStateTests {
    @Test func startRunEntersFirstRoundIntro() {
        var h = RunHarness()
        let produced = h.send(.startRun)
        #expect(h.state.phase == .roundIntro(h.state.plans[0]))
        #expect(produced == [.roundIntro(h.state.plans[0])])
        #expect(h.state.lives == 3)
        #expect(h.state.score == 0)
    }

    @Test func startRoundShowsFirstItemWithFullWindow() throws {
        var h = RunHarness()
        h.send(.startRun)
        let produced = h.send(.startRound, after: .seconds(1))
        let active = try #require(h.activeItem)
        #expect(active.index == 0)
        #expect(active.window == .seconds(2))
        #expect(active.shownAt == .seconds(1))
        #expect(active.deadline == .seconds(3))
        #expect(active.expectedEdge == h.state.currentPlan.mapping.edge(for: active.expectedCategoryID))
        #expect(produced.contains(.roundStarted(h.state.plans[0])))
        #expect(h.contains(.roundStarted, in: produced))
        #expect(produced.contains(.itemShown(active)))
        #expect(produced.contains(.wake(at: .seconds(3))))
    }

    @Test func correctAnswerScoresAndMovesToGap() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(500))
        // 100 x 1 + speed bonus 50 x (1.5 / 2.0) = 137.5, rounded to 138
        #expect(h.state.score == 138)
        #expect(h.state.streak == 1)
        #expect(h.state.lives == 3)
        #expect(h.state.phase == .betweenItems(nextItemAt: .milliseconds(750)))
        #expect(produced.contains(.scoreChanged(138)))
        #expect(h.contains(.correct(streak: 1), in: produced))
        #expect(produced.contains(.wake(at: .milliseconds(750))))
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.correct)
        #expect(result.points == 138)
        #expect(result.reaction == .milliseconds(500))
        #expect(result.answeredCategoryID == active.expectedCategoryID)
        #expect(outcome == .correct(points: 138, streak: 1))
    }

    @Test func wrongAnswerCostsALifeAndResetsStreak() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        let active = h.activeItem!
        let wrongEdge = h.state.currentPlan.mapping.edges.first { $0 != active.expectedEdge }!
        let produced = h.send(.answer(wrongEdge), after: .milliseconds(300))
        #expect(h.state.lives == 2)
        #expect(h.state.streak == 0)
        #expect(produced.contains(.livesChanged(2)))
        #expect(h.contains(.wrong, in: produced))
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(!result.correct)
        #expect(!result.timedOut)
        #expect(result.points == 0)
        #expect(result.answeredCategoryID == h.state.currentPlan.mapping.category(at: wrongEdge))
        #expect(outcome == .wrong)
    }

    @Test func timeoutCostsALife() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.tick, after: active.window)
        #expect(h.state.lives == 2)
        #expect(h.contains(.timedOut, in: produced))
        guard case .itemResolved(let result, let outcome) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.timedOut)
        #expect(result.reaction == nil)
        #expect(result.answeredCategoryID == nil)
        #expect(outcome == .timedOut)
    }

    @Test func answerAtOrAfterDeadlineIsATimeout() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: active.window)
        #expect(h.state.lives == 2)
        #expect(h.contains(.timedOut, in: produced))
        guard case .itemResolved(let result, _) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.timedOut)
        #expect(result.answeredCategoryID == nil)
    }

    @Test func tickBeforeDeadlineOnlyReschedules() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        let produced = h.send(.tick, after: .milliseconds(100))
        #expect(produced == [.wake(at: active.deadline)])
        #expect(h.activeItem == active)
        #expect(h.state.lives == 3)
    }

    @Test func flickToUnmappedEdgeIsIgnored() {
        var h = RunHarness()
        h.startRunAndRound()
        #expect(h.state.currentPlan.mapping.edges == [.left, .right])
        let active = h.activeItem!
        let produced = h.send(.answer(.up), after: .milliseconds(100))
        #expect(produced == [.wake(at: active.deadline)])
        #expect(h.activeItem == active)
        #expect(h.state.lives == 3)
        #expect(h.state.currentRoundItems.isEmpty)
    }

    @Test func threeErrorsEndTheRunOutOfLives() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerWrong()
        h.answerWrong()
        let produced = h.send(.tick, after: h.activeItem!.window)
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .outOfLives)
        #expect(summary.completed)
        #expect(summary.rounds.count == 1)
        #expect(summary.rounds[0].cutShort)
        #expect(!summary.rounds[0].perfect)
        #expect(summary.rounds[0].items.count == 3)
        #expect(summary.roundsCompleted == 0)
        #expect(summary.livesRemaining == 0)
        #expect(produced.contains(.runEnded(summary)))
        #expect(h.contains(.runEnded, in: produced))
        #expect(!produced.contains(.roundIntro(h.state.plans[1])))
    }

    @Test func roundClockEndsRoundAndDiscardsInFlightItem() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        let produced = h.finishRoundByClock()
        #expect(h.state.phase == .roundIntro(h.state.plans[1]))
        #expect(h.state.completedRounds.count == 1)
        #expect(h.state.completedRounds[0].items.count == 1)
        #expect(!h.state.completedRounds[0].cutShort)
        #expect(produced.contains(.roundIntro(h.state.plans[1])))
        #expect(produced.contains { if case .roundEnded = $0 { true } else { false } })
    }

    @Test func perfectRoundEarnsLifeAndBonus() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerWrong()
        #expect(h.state.lives == 2)
        h.finishRoundByClock()
        h.send(.startRound)
        h.answerCorrectly()
        h.answerCorrectly()
        h.answerCorrectly()
        let scoreBefore = h.state.score
        let produced = h.finishRoundByClock()
        #expect(h.state.lives == 3)
        #expect(h.state.score == scoreBefore + 500)
        #expect(h.contains(.lifeEarned, in: produced))
        #expect(h.contains(.perfectRound, in: produced))
        #expect(h.state.completedRounds[1].perfect)
        #expect(h.state.completedRounds[1].score == h.state.completedRounds[1].items.reduce(500) { $0 + $1.points })
    }

    @Test func perfectRoundAtMaximumLivesGivesBonusButNoLife() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        let produced = h.finishRoundByClock()
        #expect(h.state.lives == 3)
        #expect(h.contains(.perfectRound, in: produced))
        #expect(!h.contains(.lifeEarned, in: produced))
        #expect(!produced.contains(.livesChanged(3)))
    }

    @Test func emptyRoundIsNotPerfect() {
        var h = RunHarness()
        h.startRunAndRound()
        let produced = h.finishRoundByClock()
        #expect(!h.state.completedRounds[0].perfect)
        #expect(!h.contains(.perfectRound, in: produced))
    }

    @Test func streakResetsAtRoundStart() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        h.answerCorrectly()
        h.answerCorrectly()
        #expect(h.state.streak == 3)
        h.finishRoundByClock()
        #expect(h.state.streak == 0)
        h.send(.startRound)
        let active = h.activeItem!
        h.send(.answer(active.expectedEdge), after: .milliseconds(500))
        #expect(h.state.streak == 1)
    }

    @Test func fifthCorrectIsAMilestoneAndScoresDouble() {
        var h = RunHarness()
        h.startRunAndRound()
        for _ in 0..<4 { h.answerCorrectly() }
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(500))
        #expect(h.state.streak == 5)
        #expect(h.contains(.streakMilestone(streak: 5), in: produced))
        #expect(!h.contains(.correct(streak: 5), in: produced))
        // 100 x 2 + 50 x (1.5 / 2.0) = 237.5, rounded to 238
        guard case .itemResolved(let result, _) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.points == 238)
    }

    @Test func windowTrimsAfterFiveStreak() {
        var h = RunHarness()
        h.startRunAndRound()
        for _ in 0..<5 { h.answerCorrectly() }
        #expect(h.activeItem?.window == .milliseconds(1950))
        h.answerWrong()
        #expect(h.activeItem?.window == .seconds(2))
    }

    @Test func fullRunEndsAfterEightRounds() {
        var h = RunHarness()
        h.send(.startRun)
        for round in 0..<8 {
            #expect(h.state.phase == .roundIntro(h.state.plans[round]))
            h.send(.startRound)
            h.answerCorrectly()
            h.finishRoundByClock()
        }
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .completedAllRounds)
        #expect(summary.rounds.count == 8)
        #expect(summary.roundsCompleted == 8)
        #expect(summary.score == h.state.score)
        #expect(summary.score == summary.rounds.reduce(0) { $0 + $1.score })
    }

    @Test func itemStreamDoesNotDependOnEarlierRoundPace() {
        var fast = RunHarness(seed: 5)
        var slow = RunHarness(seed: 5)
        fast.startRunAndRound()
        slow.startRunAndRound()
        for _ in 0..<3 { fast.answerCorrectly(reaction: .milliseconds(200)) }
        for _ in 0..<12 { slow.answerCorrectly(reaction: .milliseconds(200)) }
        fast.finishRoundByClock()
        slow.finishRoundByClock()
        fast.send(.startRound)
        slow.send(.startRound)
        #expect(fast.activeItem?.item == slow.activeItem?.item)
        for _ in 0..<5 {
            fast.answerCorrectly()
            slow.answerCorrectly()
            #expect(fast.activeItem?.item == slow.activeItem?.item)
        }
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/engine-test.sh`
Expected: compile errors for `RunState`.

- [ ] **Step 3: Implement RunState**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunState.swift`:

```swift
/// The whole game as a value. Apply events with the current time and act on the effects.
/// The engine never reads a clock; `now` is time elapsed since the caller's epoch.
public struct RunState: Sendable, Equatable {
    public let seed: UInt64
    public let pack: ContentPack
    public let configuration: RunConfiguration
    public let plans: [RoundPlan]

    public private(set) var phase: RunPhase = .notStarted
    public private(set) var roundIndex = 0
    public private(set) var lives: Int
    public private(set) var score = 0
    public private(set) var streak = 0
    public private(set) var completedRounds: [RoundResult] = []
    public private(set) var currentRoundItems: [ItemResult] = []

    private var sequencer: ItemSequencer?
    private var nextItemIndex = 0
    private var roundResumedAt: Duration = .zero
    private var roundElapsedBeforeResume: Duration = .zero

    public init(pack: ContentPack, configuration: RunConfiguration = .standard, seed: UInt64) {
        self.pack = pack
        self.configuration = configuration
        self.seed = seed
        var generator = SeededGenerator(seed: seed)
        self.plans = RoundPlanner.plan(pack: pack, configuration: configuration, using: &generator)
        self.lives = configuration.startingLives
    }

    public var currentPlan: RoundPlan { plans[roundIndex] }

    public var isRoundActive: Bool {
        switch phase {
        case .playing, .betweenItems, .paused: true
        default: false
        }
    }

    /// Time left on the round clock. Zero when no round is active.
    public func roundTimeRemaining(at now: Duration) -> Duration {
        guard isRoundActive else { return .zero }
        return max(configuration.roundDuration - roundElapsed(at: now), .zero)
    }

    // MARK: - Events

    public mutating func apply(_ event: RunEvent, at now: Duration) -> [RunEffect] {
        switch (phase, event) {
        case (.notStarted, .startRun):
            phase = .roundIntro(plans[0])
            return [.roundIntro(plans[0])]

        case (.roundIntro(let plan), .startRound):
            return beginRound(plan, at: now)

        case (.playing(let active), .answer(let edge)):
            if roundClockExpired(at: now) {
                return endRound(cutShort: false)
            }
            if now >= active.deadline {
                return resolve(active, answeredEdge: nil, at: now)
            }
            guard currentPlan.mapping.category(at: edge) != nil else {
                return [.wake(at: min(active.deadline, roundDeadline(at: now)))]
            }
            return resolve(active, answeredEdge: edge, at: now)

        case (.playing(let active), .tick):
            if roundClockExpired(at: now) {
                return endRound(cutShort: false)
            }
            if now >= active.deadline {
                return resolve(active, answeredEdge: nil, at: now)
            }
            return [.wake(at: min(active.deadline, roundDeadline(at: now)))]

        case (.betweenItems(let nextItemAt), .tick):
            if roundClockExpired(at: now) {
                return endRound(cutShort: false)
            }
            if now >= nextItemAt {
                return showNextItem(at: now)
            }
            return [.wake(at: min(nextItemAt, roundDeadline(at: now)))]

        case (.playing, .pause), (.betweenItems, .pause):
            roundElapsedBeforeResume = roundElapsed(at: now)
            phase = .paused(resuming: phase, pausedAt: now)
            return []

        case (.paused(let resuming, let pausedAt), .resume):
            let shift = now - pausedAt
            roundResumedAt = now
            switch resuming {
            case .playing(var active):
                active.shownAt += shift
                active.deadline += shift
                phase = .playing(active)
                return [.itemShown(active), .wake(at: min(active.deadline, roundDeadline(at: now)))]
            case .betweenItems(let nextItemAt):
                let shifted = nextItemAt + shift
                phase = .betweenItems(nextItemAt: shifted)
                return [.wake(at: min(shifted, roundDeadline(at: now)))]
            default:
                phase = resuming
                return []
            }

        case (.finished, _), (.notStarted, _):
            return []

        case (_, .quit):
            currentRoundItems = []
            sequencer = nil
            return finish(reason: .quit)

        default:
            return []
        }
    }

    // MARK: - Round clock

    private func roundElapsed(at now: Duration) -> Duration {
        if case .paused = phase { return roundElapsedBeforeResume }
        return roundElapsedBeforeResume + (now - roundResumedAt)
    }

    private func roundClockExpired(at now: Duration) -> Bool {
        roundElapsed(at: now) >= configuration.roundDuration
    }

    private func roundDeadline(at now: Duration) -> Duration {
        now + roundTimeRemaining(at: now)
    }

    // MARK: - Transitions

    private mutating func beginRound(_ plan: RoundPlan, at now: Duration) -> [RunEffect] {
        sequencer = ItemSequencer(pack: pack, plan: plan, maximumConsecutiveSameTarget: configuration.maximumConsecutiveSameTarget)
        nextItemIndex = 0
        streak = 0
        currentRoundItems = []
        roundResumedAt = now
        roundElapsedBeforeResume = .zero
        var effects: [RunEffect] = [.roundStarted(plan), .feedback(.roundStarted)]
        effects += showNextItem(at: now)
        return effects
    }

    private mutating func showNextItem(at now: Duration) -> [RunEffect] {
        guard var sequencer else { preconditionFailure("No sequencer for the current round") }
        let draw = sequencer.next()
        self.sequencer = sequencer
        guard let edge = currentPlan.mapping.edge(for: draw.categoryID) else {
            preconditionFailure("The planner maps every active category to an edge")
        }
        let window = configuration.itemWindow(roundIndex: roundIndex, streak: streak)
        let active = ActiveItem(
            index: nextItemIndex,
            item: draw.item,
            expectedCategoryID: draw.categoryID,
            expectedEdge: edge,
            shownAt: now,
            deadline: now + window,
            window: window
        )
        nextItemIndex += 1
        phase = .playing(active)
        return [.itemShown(active), .wake(at: min(active.deadline, roundDeadline(at: now)))]
    }

    private mutating func resolve(_ active: ActiveItem, answeredEdge: Edge?, at now: Duration) -> [RunEffect] {
        let plan = currentPlan
        let timedOut = answeredEdge == nil
        let correct = answeredEdge == active.expectedEdge
        let reaction: Duration? = timedOut ? nil : now - active.shownAt
        var points = 0
        let outcome: ItemOutcome

        if correct, let reaction {
            streak += 1
            points = configuration.scoring.points(streak: streak, reaction: reaction, window: active.window)
            score += points
            outcome = .correct(points: points, streak: streak)
        } else {
            streak = 0
            lives -= 1
            outcome = timedOut ? .timedOut : .wrong
        }

        let result = ItemResult(
            roundIndex: roundIndex,
            itemIndex: active.index,
            dimensionID: plan.dimensionID,
            attributes: active.item.attributes,
            expectedCategoryID: active.expectedCategoryID,
            answeredCategoryID: answeredEdge.flatMap { plan.mapping.category(at: $0) },
            correct: correct,
            timedOut: timedOut,
            reaction: reaction,
            window: active.window,
            points: points
        )
        currentRoundItems.append(result)

        var effects: [RunEffect] = [.itemResolved(result, outcome)]
        switch outcome {
        case .correct:
            effects.append(.scoreChanged(score))
            let every = configuration.streakStep
            if every > 0, streak % every == 0 {
                effects.append(.feedback(.streakMilestone(streak: streak)))
            } else {
                effects.append(.feedback(.correct(streak: streak)))
            }
        case .wrong:
            effects.append(.livesChanged(lives))
            effects.append(.feedback(.wrong))
        case .timedOut:
            effects.append(.livesChanged(lives))
            effects.append(.feedback(.timedOut))
        }

        if lives <= 0 {
            effects += endRound(cutShort: true)
            return effects
        }

        let nextItemAt = now + configuration.interItemDelay
        phase = .betweenItems(nextItemAt: nextItemAt)
        effects.append(.wake(at: min(nextItemAt, roundDeadline(at: now))))
        return effects
    }

    private mutating func endRound(cutShort: Bool) -> [RunEffect] {
        let plan = currentPlan
        let perfect = !cutShort && !currentRoundItems.isEmpty && currentRoundItems.allSatisfy(\.correct)
        var roundScore = currentRoundItems.reduce(0) { $0 + $1.points }
        var effects: [RunEffect] = []

        if perfect {
            roundScore += configuration.scoring.perfectRoundBonus
            score += configuration.scoring.perfectRoundBonus
            effects.append(.scoreChanged(score))
            effects.append(.feedback(.perfectRound))
            if lives < configuration.maximumLives {
                lives += 1
                effects.append(.livesChanged(lives))
                effects.append(.feedback(.lifeEarned))
            }
        }

        let result = RoundResult(
            index: plan.index,
            dimensionID: plan.dimensionID,
            categoryCount: plan.activeCategoryIDs.count,
            perfect: perfect,
            cutShort: cutShort,
            score: roundScore,
            items: currentRoundItems
        )
        completedRounds.append(result)
        currentRoundItems = []
        streak = 0
        sequencer = nil
        effects.append(.roundEnded(result))

        if cutShort {
            effects += finish(reason: .outOfLives)
        } else if roundIndex + 1 < plans.count {
            roundIndex += 1
            phase = .roundIntro(plans[roundIndex])
            effects.append(.roundIntro(plans[roundIndex]))
        } else {
            effects += finish(reason: .completedAllRounds)
        }
        return effects
    }

    private mutating func finish(reason: RunEndReason) -> [RunEffect] {
        let summary = RunSummary(
            seed: seed,
            packID: pack.id,
            score: score,
            livesRemaining: lives,
            endReason: reason,
            rounds: completedRounds
        )
        phase = .finished(summary)
        var effects: [RunEffect] = [.runEnded(summary)]
        if reason != .quit {
            effects.append(.feedback(.runEnded))
        }
        return effects
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): run state machine with items, lives, scoring and round clock"
```

## Chunk 3: Engine pause, statistics and daily seed

### Task 8: Pause, resume and quit

**Files:**
- Modify: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunState.swift` (only if a test fails; the Task 7 implementation already contains pause, resume and quit)
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunStatePauseTests.swift`

- [ ] **Step 1: Write the tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunStatePauseTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct RunStatePauseTests {
    @Test func pauseFreezesRoundClockAndResumeShiftsDeadline() throws {
        var h = RunHarness()
        h.startRunAndRound()
        let before = h.activeItem!
        h.send(.pause, after: .milliseconds(500))
        #expect(h.state.roundTimeRemaining(at: h.now) == .milliseconds(44_500))
        #expect(h.state.roundTimeRemaining(at: h.now + .seconds(30)) == .milliseconds(44_500))
        let produced = h.send(.resume, after: .seconds(10))
        let after = try #require(h.activeItem)
        #expect(after.index == before.index)
        #expect(after.item == before.item)
        #expect(after.deadline == before.deadline + .seconds(10))
        #expect(after.shownAt == before.shownAt + .seconds(10))
        #expect(h.state.roundTimeRemaining(at: h.now) == .milliseconds(44_500))
        #expect(produced.contains(.itemShown(after)))
        #expect(produced.contains(.wake(at: after.deadline)))
    }

    @Test func reactionTimeExcludesPausedTime() {
        var h = RunHarness()
        h.startRunAndRound()
        h.send(.pause, after: .milliseconds(200))
        h.send(.resume, after: .seconds(5))
        let active = h.activeItem!
        let produced = h.send(.answer(active.expectedEdge), after: .milliseconds(300))
        guard case .itemResolved(let result, _) = produced[0] else {
            Issue.record("first effect should be itemResolved")
            return
        }
        #expect(result.reaction == .milliseconds(500))
    }

    @Test func pauseDuringGapShiftsNextItemTime() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        h.send(.answer(active.expectedEdge), after: .milliseconds(400))
        #expect(h.state.phase == .betweenItems(nextItemAt: .milliseconds(650)))
        h.send(.pause, after: .milliseconds(100))
        let produced = h.send(.resume, after: .seconds(2))
        #expect(h.state.phase == .betweenItems(nextItemAt: .milliseconds(2650)))
        #expect(produced == [.wake(at: .milliseconds(2650))])
        h.send(.tick, after: .milliseconds(150))
        #expect(h.activeItem?.index == 1)
    }

    @Test func eventsWhilePausedAreIgnored() {
        var h = RunHarness()
        h.startRunAndRound()
        let active = h.activeItem!
        h.send(.pause, after: .milliseconds(100))
        #expect(h.send(.answer(active.expectedEdge), after: .milliseconds(100)).isEmpty)
        #expect(h.send(.tick, after: .seconds(50)).isEmpty)
        #expect(h.send(.pause).isEmpty)
        if case .paused = h.state.phase {} else { Issue.record("should still be paused") }
        #expect(h.state.lives == 3)
    }

    @Test func pauseIsIgnoredOutsideActivePlay() {
        var h = RunHarness()
        h.send(.startRun)
        #expect(h.send(.pause).isEmpty)
        #expect(h.state.phase == .roundIntro(h.state.plans[0]))
        #expect(h.send(.resume).isEmpty)
    }

    @Test func quitKeepsFinishedRoundsAndMarksIncomplete() {
        var h = RunHarness()
        h.startRunAndRound()
        h.answerCorrectly()
        h.finishRoundByClock()
        h.send(.startRound)
        h.answerCorrectly()
        h.answerWrong()
        let produced = h.send(.quit)
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .quit)
        #expect(!summary.completed)
        #expect(summary.rounds.count == 1)
        #expect(summary.rounds[0].index == 0)
        #expect(summary.livesRemaining == 2)
        #expect(produced.contains(.runEnded(summary)))
        #expect(!h.contains(.runEnded, in: produced), "quit is silent: no run-end haptic or sting")
        #expect(h.send(.tick, after: .seconds(1)).isEmpty)
    }

    @Test func quitWhilePausedWorks() {
        var h = RunHarness()
        h.startRunAndRound()
        h.send(.pause, after: .milliseconds(100))
        h.send(.quit)
        guard case .finished(let summary) = h.state.phase else {
            Issue.record("run should be finished")
            return
        }
        #expect(summary.endReason == .quit)
        #expect(summary.rounds.isEmpty)
    }
}
```

- [ ] **Step 2: Run the tests**

Run: `Scripts/engine-test.sh`
Expected: all pass. If any fails, fix `RunState.apply` for the failing case and re-run; do not change the tests.

- [ ] **Step 3: Commit**

```bash
git add Packages
git commit -m "test(engine): pause, resume and quit behaviour"
```

### Task 9: Run statistics and daily seed

**Files:**
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunStatistics.swift`
- Create: `Packages/SwipeSortEngine/Sources/SwipeSortEngine/DailySeed.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunStatisticsTests.swift`
- Create: `Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/DailySeedTests.swift`

- [ ] **Step 1: Write the failing tests**

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/RunStatisticsTests.swift`:

```swift
import Testing
@testable import SwipeSortEngine

@Suite struct RunStatisticsTests {
    func item(_ index: Int, round: Int = 0, dimension: String = "colour", expected: String = "red",
              answered: String? = "red", correct: Bool = true, timedOut: Bool = false,
              reaction: Duration? = .milliseconds(500)) -> ItemResult {
        ItemResult(roundIndex: round, itemIndex: index, dimensionID: dimension, attributes: [:],
                   expectedCategoryID: expected, answeredCategoryID: answered, correct: correct,
                   timedOut: timedOut, reaction: reaction, window: .seconds(2), points: correct ? 100 : 0)
    }

    func round(_ index: Int, dimension: String = "colour", items: [ItemResult]) -> RoundResult {
        RoundResult(index: index, dimensionID: dimension, categoryCount: 2, perfect: false, cutShort: false, score: 0, items: items)
    }

    @Test func countsAndAccuracy() {
        let rounds = [round(0, items: [
            item(0),
            item(1, expected: "red", answered: "blue", correct: false),
            item(2, answered: nil, correct: false, timedOut: true, reaction: nil),
            item(3),
        ])]
        let stats = RunStatistics.compute(rounds: rounds)
        #expect(stats.resolvedCount == 4)
        #expect(stats.correctCount == 2)
        #expect(stats.wrongSwipeCount == 1)
        #expect(stats.timeoutCount == 1)
        #expect(stats.accuracy == 0.5)
    }

    @Test func emptyRunHasNilRatios() {
        let stats = RunStatistics.compute(rounds: [])
        #expect(stats.accuracy == nil)
        #expect(stats.meanReaction == nil)
        #expect(stats.switchCost == nil)
        #expect(stats.confusionPairs.isEmpty)
        #expect(stats.errorsByDimension.isEmpty)
    }

    @Test func errorsByDimensionInFirstSeenOrder() {
        let rounds = [
            round(0, dimension: "shape", items: [item(0, dimension: "shape"), item(1, dimension: "shape", answered: "x", correct: false)]),
            round(1, dimension: "colour", items: [item(0), item(1), item(2, answered: "blue", correct: false), item(3, answered: nil, correct: false, timedOut: true, reaction: nil)]),
        ]
        let stats = RunStatistics.compute(rounds: rounds)
        #expect(stats.errorsByDimension == [
            DimensionErrorRate(dimensionID: "shape", errors: 1, total: 2),
            DimensionErrorRate(dimensionID: "colour", errors: 2, total: 4),
        ])
        #expect(stats.errorsByDimension[1].rate == 0.5)
    }

    @Test func confusionPairsSortedByCountThenIDs() {
        let rounds = [round(0, items: [
            item(0, expected: "red", answered: "blue", correct: false),
            item(1, expected: "red", answered: "blue", correct: false),
            item(2, expected: "green", answered: "yellow", correct: false),
            item(3, expected: "blue", answered: "red", correct: false),
            item(4, expected: "red", answered: nil, correct: false, timedOut: true, reaction: nil),
        ])]
        let stats = RunStatistics.compute(rounds: rounds)
        #expect(stats.confusionPairs == [
            ConfusionPair(expectedCategoryID: "red", answeredCategoryID: "blue", count: 2),
            ConfusionPair(expectedCategoryID: "blue", answeredCategoryID: "red", count: 1),
            ConfusionPair(expectedCategoryID: "green", answeredCategoryID: "yellow", count: 1),
        ])
    }

    @Test func meanReactionUsesCorrectItemsOnly() {
        let rounds = [round(0, items: [
            item(0, reaction: .milliseconds(400)),
            item(1, reaction: .milliseconds(600)),
            item(2, answered: "blue", correct: false, reaction: .milliseconds(5000)),
        ])]
        #expect(RunStatistics.compute(rounds: rounds).meanReaction == .milliseconds(500))
    }

    @Test func switchCostIsLeadingMinusRest() {
        // First three correct items average 900 ms, the rest average 500 ms: cost 400 ms.
        let roundA = round(0, items: [
            item(0, reaction: .milliseconds(1000)),
            item(1, answered: "blue", correct: false, reaction: .milliseconds(100)),
            item(2, reaction: .milliseconds(900)),
            item(3, reaction: .milliseconds(800)),
            item(4, reaction: .milliseconds(500)),
            item(5, reaction: .milliseconds(500)),
            item(6, reaction: .milliseconds(500)),
        ])
        // Only five correct items: does not qualify.
        let roundB = round(1, items: (0..<5).map { item($0, reaction: .milliseconds(300)) })
        let stats = RunStatistics.compute(rounds: [roundA, roundB])
        #expect(stats.switchCost == .milliseconds(400))
    }

    @Test func switchCostAveragesAcrossQualifyingRounds() {
        let roundA = round(0, items: [800, 800, 800, 400, 400, 400].enumerated().map { item($0.offset, reaction: .milliseconds($0.element)) })
        let roundB = round(1, items: [600, 600, 600, 400, 400, 400].enumerated().map { item($0.offset, reaction: .milliseconds($0.element)) })
        #expect(RunStatistics.compute(rounds: [roundA, roundB]).switchCost == .milliseconds(300))
    }
}
```

`Packages/SwipeSortEngine/Tests/SwipeSortEngineTests/DailySeedTests.swift`:

```swift
import Foundation
import Testing
@testable import SwipeSortEngine

@Suite struct DailySeedTests {
    func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    let lateEvening = Date(timeIntervalSince1970: 1_790_292_600) // 2026-09-24T23:30:00Z

    @Test func dayKeyUsesLocalCalendarDate() {
        #expect(DailySeed.dayKey(for: lateEvening, calendar: calendar("UTC")) == "2026-09-24")
        #expect(DailySeed.dayKey(for: lateEvening, calendar: calendar("Europe/Paris")) == "2026-09-25")
        #expect(DailySeed.dayKey(for: lateEvening, calendar: calendar("America/Los_Angeles")) == "2026-09-24")
    }

    @Test func sameDayKeySameSeed() {
        #expect(DailySeed.seed(forDayKey: "2026-09-24") == DailySeed.seed(forDayKey: "2026-09-24"))
        #expect(DailySeed.seed(forDayKey: "2026-09-24") != DailySeed.seed(forDayKey: "2026-09-25"))
    }

    @Test func seedForDateMatchesSeedForKey() {
        let utc = calendar("UTC")
        #expect(DailySeed.seed(for: lateEvening, calendar: utc) == DailySeed.seed(forDayKey: "2026-09-24"))
    }

    @Test func dailyRunIsIdenticalForSameDay() {
        let seed = DailySeed.seed(forDayKey: "2026-09-24")
        var a = RunHarness(seed: seed)
        var b = RunHarness(seed: seed)
        a.startRunAndRound()
        b.startRunAndRound()
        #expect(a.state.plans == b.state.plans)
        #expect(a.activeItem?.item == b.activeItem?.item)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/engine-test.sh`
Expected: compile errors for `RunStatistics`, `DimensionErrorRate`, `ConfusionPair`, `DailySeed`.

- [ ] **Step 3: Implement statistics and the daily seed**

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunStatistics.swift`:

```swift
public struct DimensionErrorRate: Sendable, Equatable {
    public var dimensionID: String
    public var errors: Int
    public var total: Int

    public init(dimensionID: String, errors: Int, total: Int) {
        self.dimensionID = dimensionID
        self.errors = errors
        self.total = total
    }

    public var rate: Double { total > 0 ? Double(errors) / Double(total) : 0 }
}

public struct ConfusionPair: Sendable, Equatable {
    public var expectedCategoryID: String
    public var answeredCategoryID: String
    public var count: Int

    public init(expectedCategoryID: String, answeredCategoryID: String, count: Int) {
        self.expectedCategoryID = expectedCategoryID
        self.answeredCategoryID = answeredCategoryID
        self.count = count
    }
}

/// The per-run breakdown shown on Results and used by History.
public struct RunStatistics: Sendable, Equatable {
    public var resolvedCount: Int
    public var correctCount: Int
    public var wrongSwipeCount: Int
    public var timeoutCount: Int
    /// In the order dimensions were first played.
    public var errorsByDimension: [DimensionErrorRate]
    /// Sorted by count descending, then expected id, then answered id.
    public var confusionPairs: [ConfusionPair]
    /// Over correct items only.
    public var meanReaction: Duration?
    /// Mean over qualifying rounds of (mean of first `leadingItemCount` correct reactions
    /// minus mean of the remaining correct reactions). Nil when no round qualifies.
    public var switchCost: Duration?

    public var accuracy: Double? {
        resolvedCount > 0 ? Double(correctCount) / Double(resolvedCount) : nil
    }

    public static func compute(rounds: [RoundResult], leadingItemCount: Int = 3, minimumCorrectItems: Int = 6) -> RunStatistics {
        let items = rounds.flatMap(\.items)
        let correct = items.filter(\.correct)
        let wrong = items.filter { !$0.correct && !$0.timedOut }
        let timeouts = items.filter(\.timedOut)

        var dimensionOrder: [String] = []
        var errorsByDimension: [String: DimensionErrorRate] = [:]
        for item in items {
            if errorsByDimension[item.dimensionID] == nil {
                dimensionOrder.append(item.dimensionID)
                errorsByDimension[item.dimensionID] = DimensionErrorRate(dimensionID: item.dimensionID, errors: 0, total: 0)
            }
            errorsByDimension[item.dimensionID]!.total += 1
            if !item.correct {
                errorsByDimension[item.dimensionID]!.errors += 1
            }
        }

        struct PairKey: Hashable { let expected: String; let answered: String }
        var pairCounts: [PairKey: Int] = [:]
        for item in wrong {
            guard let answered = item.answeredCategoryID else { continue }
            pairCounts[PairKey(expected: item.expectedCategoryID, answered: answered), default: 0] += 1
        }
        let confusionPairs = pairCounts
            .map { ConfusionPair(expectedCategoryID: $0.key.expected, answeredCategoryID: $0.key.answered, count: $0.value) }
            .sorted { a, b in
                if a.count != b.count { return a.count > b.count }
                if a.expectedCategoryID != b.expectedCategoryID { return a.expectedCategoryID < b.expectedCategoryID }
                return a.answeredCategoryID < b.answeredCategoryID
            }

        let switchCosts: [Duration] = rounds.compactMap { round in
            let reactions = round.items.filter(\.correct).compactMap(\.reaction)
            guard reactions.count >= minimumCorrectItems,
                  let leading = mean(Array(reactions.prefix(leadingItemCount))),
                  let rest = mean(Array(reactions.dropFirst(leadingItemCount)))
            else { return nil }
            return leading - rest
        }

        return RunStatistics(
            resolvedCount: items.count,
            correctCount: correct.count,
            wrongSwipeCount: wrong.count,
            timeoutCount: timeouts.count,
            errorsByDimension: dimensionOrder.compactMap { errorsByDimension[$0] },
            confusionPairs: confusionPairs,
            meanReaction: mean(correct.compactMap(\.reaction)),
            switchCost: mean(switchCosts)
        )
    }

    static func mean(_ durations: [Duration]) -> Duration? {
        guard !durations.isEmpty else { return nil }
        return durations.reduce(.zero, +) / durations.count
    }
}
```

`Packages/SwipeSortEngine/Sources/SwipeSortEngine/DailySeed.swift`:

```swift
import Foundation

/// Turns a calendar day into a run seed so every play of a day's challenge is identical.
public enum DailySeed {
    /// "yyyy-MM-dd" in the given calendar's time zone.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    /// FNV-1a 64-bit hash of the day key.
    public static func seed(forDayKey key: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }

    public static func seed(for date: Date, calendar: Calendar = .current) -> UInt64 {
        seed(forDayKey: dayKey(for: date, calendar: calendar))
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `Scripts/engine-test.sh`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add Packages
git commit -m "feat(engine): run statistics and daily seed"
```

## Chunk 4: Xcode project scaffold

### Task 10: Xcode project, app skeleton and build scripts

The project is written by hand in the Xcode 16+ format with file system synchronized folders, so new files added under `WatchGame/` and `WatchGameTests/` are picked up without editing the project. Three targets: `WatchGameContainer` (the iOS container Apple's watch-only packaging requires; it has no source files), `WatchGame` (the watch app) and `WatchGameTests` (watch unit tests). Object identifiers are fixed 24-character hex strings so the scheme file can reference them.

**Files:**
- Create: `WatchGame.xcodeproj/project.pbxproj`
- Create: `WatchGame.xcodeproj/xcshareddata/xcschemes/WatchGame.xcscheme`
- Create: `WatchGame/WatchGameApp.swift`
- Create: `WatchGame/Views/Home/HomeView.swift` (placeholder, replaced in Task 18)
- Create: `WatchGame/Assets.xcassets/Contents.json`
- Create: `WatchGame/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `WatchGame/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `WatchGame/Localizable.xcstrings`
- Create: `WatchGame/PrivacyInfo.xcprivacy`
- Create: `WatchGameTests/SmokeTests.swift`
- Create: `Scripts/build.sh`
- Create: `Scripts/test.sh`

- [ ] **Step 1: Create the project file**

`WatchGame.xcodeproj/project.pbxproj`:

```
// !$*UTF8*$!
{
	archiveVersion = 1;
	classes = {
	};
	objectVersion = 77;
	objects = {

/* Begin PBXBuildFile section */
		AA000000000000000000A10A /* SwipeSortEngine in Frameworks */ = {isa = PBXBuildFile; productRef = AA000000000000000000A109 /* SwipeSortEngine */; };
		AA000000000000000000A205 /* WatchGame.app in Embed Watch Content */ = {isa = PBXBuildFile; fileRef = AA000000000000000000A101 /* WatchGame.app */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
		AA000000000000000000A30C /* SwipeSortEngine in Frameworks */ = {isa = PBXBuildFile; productRef = AA000000000000000000A30B /* SwipeSortEngine */; };
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		AA000000000000000000A20A /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = AA00000000000000000000A1 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AA000000000000000000A100;
			remoteInfo = WatchGame;
		};
		AA000000000000000000A30A /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = AA00000000000000000000A1 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AA000000000000000000A100;
			remoteInfo = WatchGame;
		};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		AA000000000000000000A204 /* Embed Watch Content */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "$(CONTENTS_FOLDER_PATH)/Watch";
			dstSubfolderSpec = 16;
			files = (
				AA000000000000000000A205 /* WatchGame.app in Embed Watch Content */,
			);
			name = "Embed Watch Content";
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
		AA000000000000000000A101 /* WatchGame.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WatchGame.app; sourceTree = BUILT_PRODUCTS_DIR; };
		AA000000000000000000A201 /* WatchGameContainer.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WatchGameContainer.app; sourceTree = BUILT_PRODUCTS_DIR; };
		AA000000000000000000A301 /* WatchGameTests.xctest */ = {isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = WatchGameTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; };
/* End PBXFileReference section */

/* Begin PBXFileSystemSynchronizedRootGroup section */
		AA000000000000000000A102 /* WatchGame */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = WatchGame;
			sourceTree = "<group>";
		};
		AA000000000000000000A302 /* WatchGameTests */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = WatchGameTests;
			sourceTree = "<group>";
		};
/* End PBXFileSystemSynchronizedRootGroup section */

/* Begin PBXFrameworksBuildPhase section */
		AA000000000000000000A104 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA000000000000000000A10A /* SwipeSortEngine in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA000000000000000000A304 /* Frameworks */ = {
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				AA000000000000000000A30C /* SwipeSortEngine in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		AA00000000000000000000A2 = {
			isa = PBXGroup;
			children = (
				AA000000000000000000A102 /* WatchGame */,
				AA000000000000000000A302 /* WatchGameTests */,
				AA00000000000000000000A3 /* Products */,
			);
			sourceTree = "<group>";
		};
		AA00000000000000000000A3 /* Products */ = {
			isa = PBXGroup;
			children = (
				AA000000000000000000A201 /* WatchGameContainer.app */,
				AA000000000000000000A101 /* WatchGame.app */,
				AA000000000000000000A301 /* WatchGameTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		AA000000000000000000A100 /* WatchGame */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA000000000000000000A106 /* Build configuration list for PBXNativeTarget "WatchGame" */;
			buildPhases = (
				AA000000000000000000A103 /* Sources */,
				AA000000000000000000A104 /* Frameworks */,
				AA000000000000000000A105 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				AA000000000000000000A102 /* WatchGame */,
			);
			name = WatchGame;
			packageProductDependencies = (
				AA000000000000000000A109 /* SwipeSortEngine */,
			);
			productName = WatchGame;
			productReference = AA000000000000000000A101 /* WatchGame.app */;
			productType = "com.apple.product-type.application";
		};
		AA000000000000000000A200 /* WatchGameContainer */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA000000000000000000A206 /* Build configuration list for PBXNativeTarget "WatchGameContainer" */;
			buildPhases = (
				AA000000000000000000A203 /* Resources */,
				AA000000000000000000A204 /* Embed Watch Content */,
			);
			buildRules = (
			);
			dependencies = (
				AA000000000000000000A209 /* PBXTargetDependency */,
			);
			name = WatchGameContainer;
			packageProductDependencies = (
			);
			productName = WatchGameContainer;
			productReference = AA000000000000000000A201 /* WatchGameContainer.app */;
			productType = "com.apple.product-type.application.watchapp2-container";
		};
		AA000000000000000000A300 /* WatchGameTests */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA000000000000000000A306 /* Build configuration list for PBXNativeTarget "WatchGameTests" */;
			buildPhases = (
				AA000000000000000000A303 /* Sources */,
				AA000000000000000000A304 /* Frameworks */,
				AA000000000000000000A305 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				AA000000000000000000A309 /* PBXTargetDependency */,
			);
			fileSystemSynchronizedGroups = (
				AA000000000000000000A302 /* WatchGameTests */,
			);
			name = WatchGameTests;
			packageProductDependencies = (
				AA000000000000000000A30B /* SwipeSortEngine */,
			);
			productName = WatchGameTests;
			productReference = AA000000000000000000A301 /* WatchGameTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		AA00000000000000000000A1 /* Project object */ = {
			isa = PBXProject;
			attributes = {
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 2700;
				LastUpgradeCheck = 2700;
				TargetAttributes = {
					AA000000000000000000A100 = {
						CreatedOnToolsVersion = 27.0;
					};
					AA000000000000000000A200 = {
						CreatedOnToolsVersion = 27.0;
					};
					AA000000000000000000A300 = {
						CreatedOnToolsVersion = 27.0;
						TestTargetID = AA000000000000000000A100;
					};
				};
			};
			buildConfigurationList = AA00000000000000000000B1 /* Build configuration list for PBXProject "WatchGame" */;
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = AA00000000000000000000A2;
			minimizedProjectReferenceProxies = 1;
			packageReferences = (
				AA00000000000000000000C1 /* XCLocalSwiftPackageReference "Packages/SwipeSortEngine" */,
			);
			preferredProjectObjectVersion = 77;
			productRefGroup = AA00000000000000000000A3 /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				AA000000000000000000A200 /* WatchGameContainer */,
				AA000000000000000000A100 /* WatchGame */,
				AA000000000000000000A300 /* WatchGameTests */,
			);
		};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		AA000000000000000000A105 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA000000000000000000A203 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA000000000000000000A305 /* Resources */ = {
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		AA000000000000000000A103 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
		AA000000000000000000A303 /* Sources */ = {
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		AA000000000000000000A209 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AA000000000000000000A100 /* WatchGame */;
			targetProxy = AA000000000000000000A20A /* PBXContainerItemProxy */;
		};
		AA000000000000000000A309 /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AA000000000000000000A100 /* WatchGame */;
			targetProxy = AA000000000000000000A30A /* PBXContainerItemProxy */;
		};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		AA00000000000000000000B2 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_STRICT_CONCURRENCY = complete;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
			};
			name = Debug;
		};
		AA00000000000000000000B3 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_USER_SCRIPT_SANDBOXING = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SWIFT_APPROACHABLE_CONCURRENCY = YES;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;
				SWIFT_STRICT_CONCURRENCY = complete;
				SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES;
				SWIFT_VERSION = 6.0;
				VALIDATE_PRODUCT = YES;
			};
			name = Release;
		};
		AA000000000000000000A107 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Swipe Sort";
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
				INFOPLIST_KEY_WKWatchOnly = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort.watchkitapp;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 4;
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
			};
			name = Debug;
		};
		AA000000000000000000A108 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Swipe Sort";
				INFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown";
				INFOPLIST_KEY_WKWatchOnly = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort.watchkitapp;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 4;
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
			};
			name = Release;
		};
		AA000000000000000000A207 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Swipe Sort";
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Debug;
		};
		AA000000000000000000A208 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = "Swipe Sort";
				IPHONEOS_DEPLOYMENT_TARGET = 26.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = iphoneos;
				TARGETED_DEVICE_FAMILY = "1,2";
			};
			name = Release;
		};
		AA000000000000000000A307 /* Debug */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort.watchkitapp.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SWIFT_EMIT_LOC_STRINGS = NO;
				TARGETED_DEVICE_FAMILY = 4;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/WatchGame.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WatchGame";
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
			};
			name = Debug;
		};
		AA000000000000000000A308 /* Release */ = {
			isa = XCBuildConfiguration;
			buildSettings = {
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort.watchkitapp.tests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SWIFT_EMIT_LOC_STRINGS = NO;
				TARGETED_DEVICE_FAMILY = 4;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/WatchGame.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/WatchGame";
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
			};
			name = Release;
		};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		AA00000000000000000000B1 /* Build configuration list for PBXProject "WatchGame" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA00000000000000000000B2 /* Debug */,
				AA00000000000000000000B3 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AA000000000000000000A106 /* Build configuration list for PBXNativeTarget "WatchGame" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA000000000000000000A107 /* Debug */,
				AA000000000000000000A108 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AA000000000000000000A206 /* Build configuration list for PBXNativeTarget "WatchGameContainer" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA000000000000000000A207 /* Debug */,
				AA000000000000000000A208 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
		AA000000000000000000A306 /* Build configuration list for PBXNativeTarget "WatchGameTests" */ = {
			isa = XCConfigurationList;
			buildConfigurations = (
				AA000000000000000000A307 /* Debug */,
				AA000000000000000000A308 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
		AA00000000000000000000C1 /* XCLocalSwiftPackageReference "Packages/SwipeSortEngine" */ = {
			isa = XCLocalSwiftPackageReference;
			relativePath = Packages/SwipeSortEngine;
		};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
		AA000000000000000000A109 /* SwipeSortEngine */ = {
			isa = XCSwiftPackageProductDependency;
			productName = SwipeSortEngine;
		};
		AA000000000000000000A30B /* SwipeSortEngine */ = {
			isa = XCSwiftPackageProductDependency;
			productName = SwipeSortEngine;
		};
/* End XCSwiftPackageProductDependency section */
	};
	rootObject = AA00000000000000000000A1 /* Project object */;
}
```

- [ ] **Step 2: Create the shared scheme**

`WatchGame.xcodeproj/xcshareddata/xcschemes/WatchGame.xcscheme`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "2700"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "AA000000000000000000A100"
               BuildableName = "WatchGame.app"
               BlueprintName = "WatchGame"
               ReferencedContainer = "container:WatchGame.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "AA000000000000000000A300"
               BuildableName = "WatchGameTests.xctest"
               BlueprintName = "WatchGameTests"
               ReferencedContainer = "container:WatchGame.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "AA000000000000000000A100"
            BuildableName = "WatchGame.app"
            BlueprintName = "WatchGame"
            ReferencedContainer = "container:WatchGame.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "AA000000000000000000A100"
            BuildableName = "WatchGame.app"
            BlueprintName = "WatchGame"
            ReferencedContainer = "container:WatchGame.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
```

- [ ] **Step 3: Create the app skeleton**

`WatchGame/WatchGameApp.swift`:

```swift
import SwiftUI

@main
struct WatchGameApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
```

`WatchGame/Views/Home/HomeView.swift` (placeholder that proves the engine links; replaced in Task 18):

```swift
import SwiftUI
import SwipeSortEngine

struct HomeView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Swipe Sort")
                    .font(.headline)
                Text("\(ContentPack.shapesAndColours.items.count) items ready")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HomeView()
}
```

`WatchGame/Assets.xcassets/Contents.json`:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`WatchGame/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [
    {
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`WatchGame/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    {
      "idiom" : "universal",
      "platform" : "watchos",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

`WatchGame/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
  },
  "version" : "1.0"
}
```

`WatchGame/PrivacyInfo.xcprivacy`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSPrivacyTracking</key>
	<false/>
	<key>NSPrivacyTrackingDomains</key>
	<array/>
	<key>NSPrivacyCollectedDataTypes</key>
	<array/>
	<key>NSPrivacyAccessedAPITypes</key>
	<array>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryUserDefaults</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>CA92.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>C617.1</string>
			</array>
		</dict>
		<dict>
			<key>NSPrivacyAccessedAPIType</key>
			<string>NSPrivacyAccessedAPICategorySystemBootTime</string>
			<key>NSPrivacyAccessedAPITypeReasons</key>
			<array>
				<string>35F9.1</string>
			</array>
		</dict>
	</array>
</dict>
</plist>
```

`WatchGameTests/SmokeTests.swift`:

```swift
import Testing
import SwipeSortEngine
@testable import WatchGame

@Suite struct SmokeTests {
    @Test func engineIsLinked() {
        #expect(ContentPack.shapesAndColours.items.count == 16)
    }
}
```

- [ ] **Step 4: Create the build and test scripts**

`Scripts/build.sh`:

```bash
#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
xcodebuild -project WatchGame.xcodeproj -scheme WatchGame \
  -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath .build/DerivedData \
  -quiet CODE_SIGNING_ALLOWED=NO build "$@"
echo "BUILD OK"
```

`Scripts/test.sh`:

```bash
#!/bin/zsh
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
DEVICE="${WATCH_SIM:-Apple Watch Series 11 (46mm)}"
if ! xcrun simctl list devices available | grep -q "$DEVICE ("; then
  DEVICE=$(xcrun simctl list devices available | grep -m1 -E '^\s+Apple Watch' | sed -E 's/^\s+(.*) \([0-9A-F-]{36}\).*/\1/')
  [[ -n "$DEVICE" ]] || { echo "No watchOS simulator available; create one with xcrun simctl create" >&2; exit 1; }
  echo "using simulator: $DEVICE"
fi
xcodebuild -project WatchGame.xcodeproj -scheme WatchGame \
  -destination "platform=watchOS Simulator,name=${DEVICE}" \
  -derivedDataPath .build/DerivedData \
  -quiet CODE_SIGNING_ALLOWED=NO test "$@"
echo "TESTS OK"
```

Run `chmod +x Scripts/build.sh Scripts/test.sh`.

- [ ] **Step 5: Build for the simulator**

Run: `Scripts/build.sh`
Expected: `BUILD OK`. If xcodebuild reports the project cannot be opened, the pbxproj has a syntax slip: run `plutil -lint WatchGame.xcodeproj/project.pbxproj` to locate it. If it reports a missing package product, check `relativePath = Packages/SwipeSortEngine` matches the folder.

- [ ] **Step 6: Run the watch unit tests**

Run: `Scripts/test.sh`
Expected: `TESTS OK` with 1 test passing. The first run boots the simulator and takes a couple of minutes.

- [ ] **Step 7: Commit**

```bash
git add WatchGame.xcodeproj WatchGame WatchGameTests Scripts
git commit -m "feat(app): watchOS app scaffold with container target, tests and build scripts"
```

## Chunk 5: Packs, persistence and feedback

### Task 11: Pack loader

**Files:**
- Create: `WatchGame/Packs/PackLoader.swift`
- Create: `WatchGameTests/PackLoaderTests.swift`
- Create: `WatchGameTests/Fixtures/broken.pack.json`
- Create: `WatchGameTests/Fixtures/valid.pack.json`

- [ ] **Step 1: Write the fixtures and the failing tests**

`WatchGameTests/Fixtures/valid.pack.json`:

```json
{
  "id": "fixture-valid",
  "nameKey": "pack.fixture",
  "dimensions": [
    { "id": "kind", "nameKey": "dimension.kind", "values": [
      { "id": "a", "labelKey": "kind.a" },
      { "id": "b", "labelKey": "kind.b" }
    ] }
  ],
  "items": [
    { "id": "a1", "attributes": { "kind": "a" }, "visual": { "type": "shape", "kind": "circle", "colour": "#0072B2" } },
    { "id": "b1", "attributes": { "kind": "b" }, "visual": { "type": "shape", "kind": "square", "colour": "#D55E00" } },
    { "id": "b2", "attributes": { "kind": "b" }, "visual": { "type": "image", "assetName": "fixture-image" } }
  ]
}
```

`WatchGameTests/Fixtures/broken.pack.json`:

```json
{
  "id": "fixture-broken",
  "nameKey": "pack.broken",
  "dimensions": [
    { "id": "kind", "nameKey": "dimension.kind", "values": [
      { "id": "a", "labelKey": "kind.a" },
      { "id": "b", "labelKey": "kind.b" }
    ] }
  ],
  "items": [
    { "id": "a1", "attributes": { "kind": "a" }, "visual": { "type": "shape", "kind": "circle", "colour": "#0072B2" } }
  ]
}
```

`WatchGameTests/PackLoaderTests.swift`:

```swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/test.sh`
Expected: compile errors for `PackLoader` and `Localization`.

- [ ] **Step 3: Implement the loader and the localisation helper**

`WatchGame/Game/Localization.swift`:

```swift
import Foundation

/// Helpers for String Catalog keys that come from pack data rather than source code.
enum Localization {
    private static let missingMarker = "\u{0}MISSING\u{0}"

    /// The localised string for a catalog key, or the key itself when the catalog has no entry.
    static func string(_ key: String, bundle: Bundle = .main) -> String {
        let value = bundle.localizedString(forKey: key, value: missingMarker, table: nil)
        return value == missingMarker ? key : value
    }

    static func hasString(_ key: String, bundle: Bundle = .main) -> Bool {
        bundle.localizedString(forKey: key, value: missingMarker, table: nil) != missingMarker
    }
}
```

`WatchGame/Packs/PackLoader.swift`:

```swift
import Foundation
import OSLog
import SwipeSortEngine

/// The packs available to play: the built-in shapes pack first, then every valid
/// `*.pack.json` in the bundle, sorted by file name.
enum PackLoader {
    private static let logger = Logger(subsystem: "com.pynto.swipesort", category: "packs")

    static func loadPacks(from bundle: Bundle = .main) -> [ContentPack] {
        var packs = [ContentPack.shapesAndColours]
        for url in packURLs(in: bundle) {
            do {
                let pack = try load(url)
                if packs.contains(where: { $0.id == pack.id }) {
                    logger.error("Skipping \(url.lastPathComponent, privacy: .public): duplicate pack id \(pack.id, privacy: .public)")
                    continue
                }
                packs.append(pack)
            } catch {
                logger.error("Skipping \(url.lastPathComponent, privacy: .public): \(String(describing: error), privacy: .public)")
            }
        }
        return packs
    }

    /// Decodes and validates every bundled pack, throwing on the first failure.
    /// Tests call this so a broken pack fails the build instead of being skipped.
    static func validateBundledPacks(in bundle: Bundle = .main) throws -> [ContentPack] {
        var packs = [ContentPack.shapesAndColours]
        for url in packURLs(in: bundle) {
            packs.append(try load(url))
        }
        return packs
    }

    private static func packURLs(in bundle: Bundle) -> [URL] {
        (bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasSuffix(".pack.json") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func load(_ url: URL) throws -> ContentPack {
        let pack = try JSONDecoder().decode(ContentPack.self, from: Data(contentsOf: url))
        try pack.validate()
        return pack
    }
}
```

- [ ] **Step 4: Add the built-in pack's strings to the String Catalog**

Replace `WatchGame/Localizable.xcstrings` with:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "colour.blue" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Blue" } } } },
    "colour.green" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Green" } } } },
    "colour.red" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Red" } } } },
    "colour.yellow" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Yellow" } } } },
    "dimension.colour" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Colour" } } } },
    "dimension.shape" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Shape" } } } },
    "hint.colour.blue" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "B" } } } },
    "hint.colour.green" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "G" } } } },
    "hint.colour.red" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "R" } } } },
    "hint.colour.yellow" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Y" } } } },
    "pack.shapes-colours" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Shapes & Colours" } } } },
    "shape.circle" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Circle" } } } },
    "shape.square" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Square" } } } },
    "shape.star" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Star" } } } },
    "shape.triangle" : { "localizations" : { "en" : { "stringUnit" : { "state" : "translated", "value" : "Triangle" } } } }
  },
  "version" : "1.0"
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `Scripts/test.sh`
Expected: `TESTS OK`. If `loaderSkipsInvalidPacksAndKeepsValidOnes` finds no fixtures, confirm the `Fixtures` folder sits under `WatchGameTests/` so the synchronized group copies the JSON files into the test bundle.

- [ ] **Step 6: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): pack loader with validation and localisation helper"
```

### Task 12: SwiftData history models and store

**Files:**
- Create: `WatchGame/Persistence/HistoryModels.swift`
- Create: `WatchGame/Persistence/HistoryStore.swift`
- Create: `WatchGameTests/HistoryStoreTests.swift`

- [ ] **Step 1: Write the failing tests**

`WatchGameTests/HistoryStoreTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite struct HistoryStoreTests {
    func makeStore() throws -> HistoryStore {
        let container = try ModelContainer(
            for: RunEntry.self, RoundEntry.self, ItemEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return HistoryStore(container: container)
    }

    func item(_ index: Int, correct: Bool = true) -> ItemResult {
        ItemResult(roundIndex: 0, itemIndex: index, dimensionID: "colour", attributes: ["colour": "red", "shape": "star"],
                   expectedCategoryID: "red", answeredCategoryID: correct ? "red" : "blue", correct: correct, timedOut: false,
                   reaction: .milliseconds(450), window: .seconds(2), points: correct ? 100 : 0)
    }

    func round(_ index: Int, score: Int = 200, cutShort: Bool = false) -> RoundResult {
        RoundResult(index: index, dimensionID: "colour", categoryCount: 2, perfect: false, cutShort: cutShort, score: score, items: [item(0), item(1, correct: false)])
    }

    func summary(score: Int, rounds: [RoundResult], reason: RunEndReason = .completedAllRounds) -> RunSummary {
        RunSummary(seed: 7, packID: "shapes-colours", score: score, livesRemaining: 1, endReason: reason, rounds: rounds)
    }

    @Test func runRoundTripsToResults() throws {
        let store = try makeStore()
        let run = store.beginRun(packID: "shapes-colours", isDaily: false, dailyKey: nil, seed: 7)
        store.append(round(0), to: run)
        store.append(round(1, score: 300), to: run)
        store.finish(run, summary: summary(score: 500, rounds: [round(0), round(1, score: 300)]))
        let results = run.roundResults
        #expect(results == [round(0), round(1, score: 300)])
        #expect(run.score == 500)
        #expect(run.completed)
        #expect(run.roundsCompleted == 2)
        #expect(run.endedAt != nil)
        #expect(UInt64(bitPattern: run.seed) == 7)
    }

    @Test func abandonedRunsAreMarkedIncomplete() throws {
        let store = try makeStore()
        let run = store.beginRun(packID: "shapes-colours", isDaily: false, dailyKey: nil, seed: 1)
        store.append(round(0), to: run)
        store.save()
        store.markAbandonedRuns()
        #expect(run.endedAt != nil)
        #expect(!run.completed)
        #expect(run.endReason == .abandoned)
        #expect(store.completedRuns().isEmpty)
        #expect(store.allRuns().count == 1)
    }

    @Test func bestScoreUsesCompletedRunsOnly() throws {
        let store = try makeStore()
        let good = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 1)
        store.finish(good, summary: summary(score: 900, rounds: []))
        let quit = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 2)
        store.finish(quit, summary: summary(score: 5000, rounds: [], reason: .quit))
        #expect(store.bestScore() == 900)
    }

    @Test func dailyStreakCountsConsecutiveDays() throws {
        let store = try makeStore()
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_790_208_000)) // 2026-09-24
        func play(daysAgo: Int, completed: Bool = true) {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let key = DailySeed.dayKey(for: date, calendar: calendar)
            let run = store.beginRun(packID: "p", isDaily: true, dailyKey: key, seed: 1, startedAt: date)
            store.finish(run, summary: summary(score: 100, rounds: [], reason: completed ? .completedAllRounds : .quit), endedAt: date)
        }
        #expect(store.dailyStreak(today: today, calendar: calendar) == 0)
        play(daysAgo: 1)
        play(daysAgo: 2)
        play(daysAgo: 3)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 3, "yesterday counts when today is unplayed")
        play(daysAgo: 0)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 4)
        play(daysAgo: 5)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 4, "a gap breaks the streak")
        play(daysAgo: 4, completed: false)
        #expect(store.dailyStreak(today: today, calendar: calendar) == 4, "quit runs do not count")
        #expect(store.hasCompletedDaily(dayKey: DailySeed.dayKey(for: today, calendar: calendar)))
    }

    @Test func resetRemovesEverything() throws {
        let store = try makeStore()
        let run = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 1)
        store.append(round(0), to: run)
        store.finish(run, summary: summary(score: 100, rounds: [round(0)]))
        store.reset()
        #expect(store.allRuns().isEmpty)
        #expect(store.bestScore() == nil)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/test.sh`
Expected: compile errors for `RunEntry`, `HistoryStore`.

- [ ] **Step 3: Implement the models**

`WatchGame/Persistence/HistoryModels.swift`:

```swift
import Foundation
import SwiftData
import SwipeSortEngine

// Every property has a default and every relationship is optional so the schema
// stays CloudKit-compatible if sync is enabled later.

@Model
final class RunEntry {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var endedAt: Date?
    var packID: String = ""
    var isDaily: Bool = false
    var dailyKey: String?
    /// `UInt64` bit pattern; SwiftData stores signed integers.
    var seed: Int64 = 0
    var score: Int = 0
    var roundsCompleted: Int = 0
    var livesRemaining: Int = 0
    var completed: Bool = false
    var endReasonRaw: String = RunEndReason.quit.rawValue
    @Relationship(deleteRule: .cascade, inverse: \RoundEntry.run)
    var rounds: [RoundEntry]? = []

    init(startedAt: Date, packID: String, isDaily: Bool, dailyKey: String?, seed: UInt64) {
        self.startedAt = startedAt
        self.packID = packID
        self.isDaily = isDaily
        self.dailyKey = dailyKey
        self.seed = Int64(bitPattern: seed)
    }

    var endReason: RunEndReason {
        get { RunEndReason(rawValue: endReasonRaw) ?? .quit }
        set { endReasonRaw = newValue.rawValue }
    }

    /// Rounds as engine values, in index order, for `RunStatistics`.
    var roundResults: [RoundResult] {
        (rounds ?? []).sorted { $0.index < $1.index }.map(\.result)
    }
}

@Model
final class RoundEntry {
    var index: Int = 0
    var dimensionID: String = ""
    var categoryCount: Int = 0
    var perfect: Bool = false
    var cutShort: Bool = false
    var score: Int = 0
    var run: RunEntry?
    @Relationship(deleteRule: .cascade, inverse: \ItemEntry.round)
    var items: [ItemEntry]? = []

    init(result: RoundResult) {
        index = result.index
        dimensionID = result.dimensionID
        categoryCount = result.categoryCount
        perfect = result.perfect
        cutShort = result.cutShort
        score = result.score
        items = result.items.map(ItemEntry.init(result:))
    }

    var result: RoundResult {
        RoundResult(
            index: index,
            dimensionID: dimensionID,
            categoryCount: categoryCount,
            perfect: perfect,
            cutShort: cutShort,
            score: score,
            items: (items ?? []).sorted { $0.itemIndex < $1.itemIndex }.map(\.result)
        )
    }
}

@Model
final class ItemEntry {
    var roundIndex: Int = 0
    var itemIndex: Int = 0
    var dimensionID: String = ""
    var attributes: [String: String] = [:]
    var expectedCategoryID: String = ""
    var answeredCategoryID: String?
    var correct: Bool = false
    var timedOut: Bool = false
    var reactionMilliseconds: Int?
    var windowMilliseconds: Int = 0
    var points: Int = 0
    var round: RoundEntry?

    init(result: ItemResult) {
        roundIndex = result.roundIndex
        itemIndex = result.itemIndex
        dimensionID = result.dimensionID
        attributes = result.attributes
        expectedCategoryID = result.expectedCategoryID
        answeredCategoryID = result.answeredCategoryID
        correct = result.correct
        timedOut = result.timedOut
        reactionMilliseconds = result.reaction.map(Self.milliseconds)
        windowMilliseconds = Self.milliseconds(result.window)
        points = result.points
    }

    var result: ItemResult {
        ItemResult(
            roundIndex: roundIndex,
            itemIndex: itemIndex,
            dimensionID: dimensionID,
            attributes: attributes,
            expectedCategoryID: expectedCategoryID,
            answeredCategoryID: answeredCategoryID,
            correct: correct,
            timedOut: timedOut,
            reaction: reactionMilliseconds.map { .milliseconds($0) },
            window: .milliseconds(windowMilliseconds),
            points: points
        )
    }

    static func milliseconds(_ duration: Duration) -> Int {
        Int((duration / .milliseconds(1)).rounded())
    }
}
```

- [ ] **Step 4: Implement the store**

`WatchGame/Persistence/HistoryStore.swift`:

```swift
import Foundation
import OSLog
import SwiftData
import SwipeSortEngine

/// The only object that talks to SwiftData. Main-actor bound like the views that read it.
@MainActor
final class HistoryStore {
    static let schema = Schema([RunEntry.self, RoundEntry.self, ItemEntry.self])
    private static let logger = Logger(subsystem: "com.pynto.swipesort", category: "history")

    let context: ModelContext
    /// True when the persistent store failed and an in-memory store is being used instead.
    private(set) var isFallback = false

    init(container: ModelContainer, isFallback: Bool = false) {
        context = container.mainContext
        context.autosaveEnabled = true
        self.isFallback = isFallback
    }

    /// Opens the on-disk store, or an in-memory one if that fails.
    static func open() -> HistoryStore {
        do {
            let container = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
            return HistoryStore(container: container)
        } catch {
            logger.error("Persistent store unavailable, using in-memory history: \(String(describing: error), privacy: .public)")
            let container = try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
            return HistoryStore(container: container, isFallback: true)
        }
    }

    // MARK: - Writing

    @discardableResult
    func beginRun(packID: String, isDaily: Bool, dailyKey: String?, seed: UInt64, startedAt: Date = .now) -> RunEntry {
        let run = RunEntry(startedAt: startedAt, packID: packID, isDaily: isDaily, dailyKey: dailyKey, seed: seed)
        context.insert(run)
        save()
        return run
    }

    func append(_ result: RoundResult, to run: RunEntry) {
        let entry = RoundEntry(result: result)
        entry.run = run
        context.insert(entry)
        run.rounds = (run.rounds ?? []) + [entry]
        save()
    }

    func finish(_ run: RunEntry, summary: RunSummary, endedAt: Date = .now) {
        run.endedAt = endedAt
        run.score = summary.score
        run.roundsCompleted = summary.roundsCompleted
        run.livesRemaining = summary.livesRemaining
        run.completed = summary.completed
        run.endReason = summary.endReason
        save()
    }

    /// Runs with no end time were interrupted by a process kill. Call once at launch.
    func markAbandonedRuns(at date: Date = .now) {
        let open = fetch(FetchDescriptor<RunEntry>(predicate: #Predicate { $0.endedAt == nil }))
        for run in open {
            run.endedAt = date
            run.completed = false
            run.endReason = .abandoned
            run.roundsCompleted = run.roundResults.filter { !$0.cutShort }.count
            run.score = run.roundResults.reduce(0) { $0 + $1.score }
        }
        save()
    }

    func reset() {
        for run in allRuns() {
            context.delete(run)
        }
        save()
    }

    func save() {
        do {
            try context.save()
        } catch {
            Self.logger.error("Save failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Reading

    func allRuns(limit: Int? = nil) -> [RunEntry] {
        var descriptor = FetchDescriptor<RunEntry>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    func completedRuns(limit: Int? = nil) -> [RunEntry] {
        var descriptor = FetchDescriptor<RunEntry>(
            predicate: #Predicate { $0.completed == true },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return fetch(descriptor)
    }

    func bestScore() -> Int? {
        completedRuns().map(\.score).max()
    }

    func hasCompletedDaily(dayKey: String) -> Bool {
        !fetch(FetchDescriptor<RunEntry>(predicate: #Predicate { $0.completed == true && $0.isDaily == true && $0.dailyKey == dayKey })).isEmpty
    }

    /// Consecutive days with a completed daily ending today, or ending yesterday if today is unplayed.
    func dailyStreak(today: Date = .now, calendar: Calendar = .current) -> Int {
        let played = Set(fetch(FetchDescriptor<RunEntry>(predicate: #Predicate { $0.completed == true && $0.isDaily == true })).compactMap(\.dailyKey))
        guard !played.isEmpty else { return 0 }
        var day = calendar.startOfDay(for: today)
        if !played.contains(DailySeed.dayKey(for: day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while played.contains(DailySeed.dayKey(for: day, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    private func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            Self.logger.error("Fetch failed: \(String(describing: error), privacy: .public)")
            return []
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `Scripts/test.sh`
Expected: `TESTS OK`. If `#Predicate` on `endedAt == nil` fails to compile, write it as `$0.endedAt == nil` inside the macro exactly as shown; SwiftData supports optional comparisons to nil.

- [ ] **Step 6: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): SwiftData history models and store"
```

### Task 13: Haptics, sound and the placeholder sound generator

**Files:**
- Create: `WatchGame/Feedback/HapticsService.swift`
- Create: `WatchGame/Feedback/SoundService.swift`
- Create: `Tools/generate_sounds.py`
- Create: `WatchGame/Resources/Sounds/correct.wav`, `wrong.wav`, `timeout.wav`, `roundStart.wav`, `perfect.wav`, `runEnd.wav` (generated)
- Create: `WatchGameTests/FeedbackMappingTests.swift`

- [ ] **Step 1: Write the failing test**

`WatchGameTests/FeedbackMappingTests.swift`:

```swift
import Testing
import WatchKit
import SwipeSortEngine
@testable import WatchGame

@Suite struct FeedbackMappingTests {
    @Test func hapticTableMatchesSpec() {
        #expect(FeedbackCue.correct(streak: 1).hapticType == .click)
        #expect(FeedbackCue.correct(streak: 4).hapticType == .click)
        #expect(FeedbackCue.streakMilestone(streak: 5).hapticType == .success)
        #expect(FeedbackCue.wrong.hapticType == .failure)
        #expect(FeedbackCue.timedOut.hapticType == .failure)
        #expect(FeedbackCue.lifeEarned.hapticType == .directionUp)
        #expect(FeedbackCue.roundStarted.hapticType == .start)
        #expect(FeedbackCue.runEnded.hapticType == .stop)
        #expect(FeedbackCue.perfectRound.hapticType == nil)
    }

    @Test func soundTableAndPitch() {
        #expect(FeedbackCue.correct(streak: 1).sound == SoundCue(asset: .correct, semitones: 0))
        #expect(FeedbackCue.correct(streak: 7).sound == SoundCue(asset: .correct, semitones: 6))
        #expect(FeedbackCue.streakMilestone(streak: 20).sound == SoundCue(asset: .correct, semitones: 12))
        #expect(FeedbackCue.wrong.sound == SoundCue(asset: .wrong, semitones: 0))
        #expect(FeedbackCue.timedOut.sound == SoundCue(asset: .timeout, semitones: 0))
        #expect(FeedbackCue.roundStarted.sound == SoundCue(asset: .roundStart, semitones: 0))
        #expect(FeedbackCue.perfectRound.sound == SoundCue(asset: .perfect, semitones: 0))
        #expect(FeedbackCue.runEnded.sound == SoundCue(asset: .runEnd, semitones: 0))
        #expect(FeedbackCue.lifeEarned.sound == nil)
    }

    @Test func everySoundAssetIsBundled() {
        for asset in SoundAsset.allCases {
            #expect(Bundle.main.url(forResource: asset.rawValue, withExtension: "wav") != nil, "missing \(asset.rawValue).wav")
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/test.sh`
Expected: compile errors for `hapticType`, `SoundCue`, `SoundAsset`.

- [ ] **Step 3: Implement haptics**

`WatchGame/Feedback/HapticsService.swift`:

```swift
import WatchKit
import SwipeSortEngine

@MainActor
protocol HapticsService: AnyObject {
    func play(_ cue: FeedbackCue)
}

extension FeedbackCue {
    /// The one haptic a cue maps to (spec 5.1). Nil means no haptic.
    var hapticType: WKHapticType? {
        switch self {
        case .correct: .click
        case .streakMilestone: .success
        case .wrong, .timedOut: .failure
        case .lifeEarned: .directionUp
        case .roundStarted: .start
        case .runEnded: .stop
        case .perfectRound: nil
        }
    }
}

@MainActor
final class WatchHaptics: HapticsService {
    var isEnabled: Bool

    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }

    func play(_ cue: FeedbackCue) {
        guard isEnabled, let type = cue.hapticType else { return }
        WKInterfaceDevice.current().play(type)
    }
}

@MainActor
final class SilentHaptics: HapticsService {
    func play(_ cue: FeedbackCue) {}
}
```

- [ ] **Step 4: Implement sound**

`WatchGame/Feedback/SoundService.swift`:

```swift
import AVFoundation
import OSLog
import SwipeSortEngine

enum SoundAsset: String, CaseIterable, Sendable {
    case correct, wrong, timeout, roundStart, perfect, runEnd
}

struct SoundCue: Equatable, Sendable {
    var asset: SoundAsset
    /// Pitch shift applied through the time-pitch unit.
    var semitones: Int
}

extension FeedbackCue {
    static let maximumSemitones = 12

    /// The sound a cue plays (spec 5.2). The correct sound rises one semitone per streak step.
    var sound: SoundCue? {
        switch self {
        case .correct(let streak), .streakMilestone(let streak):
            SoundCue(asset: .correct, semitones: min(max(streak - 1, 0), Self.maximumSemitones))
        case .wrong: SoundCue(asset: .wrong, semitones: 0)
        case .timedOut: SoundCue(asset: .timeout, semitones: 0)
        case .roundStarted: SoundCue(asset: .roundStart, semitones: 0)
        case .perfectRound: SoundCue(asset: .perfect, semitones: 0)
        case .runEnded: SoundCue(asset: .runEnd, semitones: 0)
        case .lifeEarned: nil
        }
    }
}

@MainActor
protocol SoundService: AnyObject {
    func play(_ cue: FeedbackCue)
}

@MainActor
final class SilentSound: SoundService {
    func play(_ cue: FeedbackCue) {}
}

/// Plays the bundled sounds through an AVAudioEngine graph with a time-pitch unit.
/// Any setup failure disables sound for the session and leaves gameplay untouched.
@MainActor
final class EngineSound: SoundService {
    private static let logger = Logger(subsystem: "com.pynto.swipesort", category: "sound")

    var isEnabled: Bool
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var buffers: [SoundAsset: AVAudioPCMBuffer] = [:]
    private var isReady = false

    init(isEnabled: Bool = true, bundle: Bundle = .main) {
        self.isEnabled = isEnabled
        do {
            try configure(bundle: bundle)
            isReady = true
        } catch {
            Self.logger.error("Sound disabled: \(String(describing: error), privacy: .public)")
        }
    }

    private func configure(bundle: Bundle) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)

        for asset in SoundAsset.allCases {
            guard let url = bundle.url(forResource: asset.rawValue, withExtension: "wav") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            try file.read(into: buffer)
            buffers[asset] = buffer
        }

        guard let format = buffers[.correct]?.format else { throw CocoaError(.fileReadCorruptFile) }
        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: format)
        engine.connect(timePitch, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
    }

    func play(_ cue: FeedbackCue) {
        guard isEnabled, isReady, let sound = cue.sound, let buffer = buffers[sound.asset] else { return }
        if !engine.isRunning {
            do { try engine.start() } catch {
                Self.logger.error("Engine restart failed: \(String(describing: error), privacy: .public)")
                return
            }
        }
        timePitch.pitch = Float(sound.semitones * 100)
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying {
            player.play()
        }
    }
}
```

- [ ] **Step 5: Write the sound generator and generate the files**

`Tools/generate_sounds.py`:

```python
#!/usr/bin/env python3
"""Generates the placeholder game sounds as 16-bit mono 44.1 kHz WAV files.

Run from anywhere: python3 Tools/generate_sounds.py
Replace the generated files with designed assets later; names and formats must stay the same.
"""
import math
import pathlib
import struct
import wave

RATE = 44_100
OUT_DIR = pathlib.Path(__file__).resolve().parent.parent / "WatchGame" / "Resources" / "Sounds"


def tone(freq_hz, length_ms, volume=0.6, attack_ms=3.0, decay_power=2.0, harmonics=(1.0,)):
    """A decaying tone with optional harmonics (amplitude per overtone)."""
    total = int(RATE * length_ms / 1000)
    attack = max(1, int(RATE * attack_ms / 1000))
    samples = []
    for i in range(total):
        t = i / RATE
        envelope = min(1.0, i / attack) * (1 - i / total) ** decay_power
        value = sum(amp * math.sin(2 * math.pi * freq_hz * (n + 1) * t) for n, amp in enumerate(harmonics))
        samples.append(volume * envelope * value / sum(harmonics))
    return samples


def sweep(start_hz, end_hz, length_ms, volume=0.5):
    total = int(RATE * length_ms / 1000)
    samples, phase = [], 0.0
    for i in range(total):
        freq = start_hz + (end_hz - start_hz) * i / total
        phase += 2 * math.pi * freq / RATE
        envelope = (1 - i / total) ** 1.5
        samples.append(volume * envelope * math.sin(phase))
    return samples


def silence(length_ms):
    return [0.0] * int(RATE * length_ms / 1000)


def write(name, samples):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{name}.wav"
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        clipped = (max(-1.0, min(1.0, s)) for s in samples)
        handle.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in clipped))
    print(f"wrote {path.relative_to(OUT_DIR.parent.parent.parent)} ({len(samples) / RATE * 1000:.0f} ms)")


SOUNDS = {
    "correct": tone(880, 110, harmonics=(1.0, 0.3)),
    "wrong": tone(110, 180, volume=0.7, harmonics=(1.0, 0.6, 0.4), decay_power=1.2),
    "timeout": sweep(600, 180, 220),
    "roundStart": tone(660, 90) + tone(990, 170),
    "perfect": tone(523, 70) + tone(659, 70) + tone(784, 70) + tone(1047, 230, harmonics=(1.0, 0.3)),
    "runEnd": tone(784, 120) + tone(659, 120) + tone(523, 260, harmonics=(1.0, 0.4)),
}

if __name__ == "__main__":
    for name, samples in SOUNDS.items():
        write(name, samples)
```

Run: `python3 Tools/generate_sounds.py`
Expected: six `wrote WatchGame/Resources/Sounds/<name>.wav` lines, each under 300 ms except `perfect` and `runEnd` which are under 500 ms.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `Scripts/test.sh`
Expected: `TESTS OK`.

- [ ] **Step 7: Commit**

```bash
git add WatchGame WatchGameTests Tools
git commit -m "feat(app): haptic and sound services with generated placeholder sounds"
```

## Chunk 6: Game session

### Task 14: App settings, environment and the game session

**Files:**
- Create: `WatchGame/Views/Settings/AppSettings.swift`
- Create: `WatchGame/AppEnvironment.swift`
- Create: `WatchGame/Game/GameSession.swift`
- Create: `WatchGameTests/GameSessionTests.swift`
- Modify: `WatchGame/WatchGameApp.swift`

- [ ] **Step 1: Write the failing tests**

`WatchGameTests/GameSessionTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite struct GameSessionTests {
    func makeSession(seed: UInt64 = 1) throws -> (GameSession, HistoryStore, RecordingHaptics) {
        let container = try ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        let history = HistoryStore(container: container)
        let haptics = RecordingHaptics()
        let session = GameSession(pack: .shapesAndColours, seed: seed, isDaily: false, dailyKey: nil,
                                  haptics: haptics, sound: SilentSound(), history: history)
        return (session, history, haptics)
    }

    @Test func startShowsRoundIntroThenFirstItem() throws {
        let (session, _, haptics) = try makeSession()
        #expect(session.screen == .roundIntro)
        session.start()
        #expect(session.screen == .roundIntro)
        #expect(session.roundNumber == 1)
        session.startRound()
        #expect(session.screen == .playing)
        #expect(session.activeItem?.index == 0)
        #expect(haptics.cues == [.roundStarted])
    }

    @Test func answeringUpdatesScoreAndRecordsHaptic() throws {
        let (session, _, haptics) = try makeSession()
        session.start()
        session.startRound()
        let item = try #require(session.activeItem)
        session.answer(item.expectedEdge)
        #expect(session.score > 0)
        #expect(session.streak == 1)
        #expect(haptics.cues.last == .correct(streak: 1))
        #expect(session.resolvedItem?.outcome == .correct(points: session.score, streak: 1))
    }

    @Test func nextItemArrivesAfterGapWithoutExternalTick() async throws {
        let (session, _, _) = try makeSession()
        session.start()
        session.startRound()
        let first = try #require(session.activeItem)
        session.answer(first.expectedEdge)
        #expect(session.activeItem == nil)
        try await Task.sleep(for: .milliseconds(600))
        #expect(session.activeItem?.index == 1)
    }

    @Test func itemTimesOutWithoutExternalTick() async throws {
        let (session, _, haptics) = try makeSession()
        session.start()
        session.startRound()
        try await Task.sleep(for: .milliseconds(2300))
        #expect(session.lives == 2)
        #expect(haptics.cues.contains(.timedOut))
    }

    @Test func pauseStopsTheClock() async throws {
        let (session, _, _) = try makeSession()
        session.start()
        session.startRound()
        session.pause()
        #expect(session.screen == .paused)
        try await Task.sleep(for: .milliseconds(2300))
        #expect(session.lives == 3)
        session.resume()
        #expect(session.screen == .playing)
        #expect(session.activeItem?.index == 0)
    }

    @Test func quitFinishesRunAsIncomplete() throws {
        let (session, history, _) = try makeSession()
        session.start()
        session.startRound()
        session.quit()
        #expect(session.screen == .results)
        #expect(session.summary?.endReason == .quit)
        let runs = history.allRuns()
        #expect(runs.count == 1)
        #expect(runs[0].completed == false)
        #expect(runs[0].endedAt != nil)
    }

    @Test func roundsArePersistedAsTheyFinish() throws {
        let (session, history, _) = try makeSession()
        session.start()
        session.startRound()
        let item = try #require(session.activeItem)
        session.answer(item.expectedEdge)
        session.debugExpireRoundClock()
        #expect(session.screen == .roundIntro)
        #expect(session.roundNumber == 2)
        #expect(session.lastRound?.perfect == true)
        #expect(history.allRuns()[0].roundResults.count == 1)
    }
}

@MainActor
final class RecordingHaptics: HapticsService {
    var cues: [FeedbackCue] = []
    func play(_ cue: FeedbackCue) { cues.append(cue) }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/test.sh`
Expected: compile errors for `GameSession`.

- [ ] **Step 3: Implement settings keys and the environment**

`WatchGame/Views/Settings/AppSettings.swift`:

```swift
import Foundation

/// UserDefaults keys for player settings. Views bind with `@AppStorage(AppSettings.x)`.
enum AppSettings {
    static let soundsEnabled = "settings.soundsEnabled"
    static let hapticsEnabled = "settings.hapticsEnabled"
    static let tapToSort = "settings.tapToSort"
    static let colourHints = "settings.colourHints"

    static func register(in defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            soundsEnabled: true,
            hapticsEnabled: true,
            tapToSort: false,
            colourHints: false,
        ])
    }
}
```

`WatchGame/AppEnvironment.swift`:

```swift
import Foundation
import Observation
import SwipeSortEngine

/// Long-lived services, built once at launch and injected through the SwiftUI environment.
@MainActor
@Observable
final class AppEnvironment {
    let history: HistoryStore
    let haptics: WatchHaptics
    let sound: EngineSound
    let packs: [ContentPack]
    /// The run in progress, if any. Set by Home, cleared when the run screen is dismissed.
    var session: GameSession?

    init(history: HistoryStore, haptics: WatchHaptics, sound: EngineSound, packs: [ContentPack]) {
        self.history = history
        self.haptics = haptics
        self.sound = sound
        self.packs = packs
    }

    static func live() -> AppEnvironment {
        AppSettings.register()
        let history = HistoryStore.open()
        history.markAbandonedRuns()
        let defaults = UserDefaults.standard
        let environment = AppEnvironment(
            history: history,
            haptics: WatchHaptics(isEnabled: defaults.bool(forKey: AppSettings.hapticsEnabled)),
            sound: EngineSound(isEnabled: defaults.bool(forKey: AppSettings.soundsEnabled)),
            packs: PackLoader.loadPacks()
        )
        return environment
    }

    /// In-memory history and no audio, for previews.
    static func preview() -> AppEnvironment {
        let container = try! ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        return AppEnvironment(
            history: HistoryStore(container: container, isFallback: true),
            haptics: WatchHaptics(isEnabled: false),
            sound: EngineSound(isEnabled: false),
            packs: [.shapesAndColours]
        )
    }

    var pack: ContentPack { packs[0] }

    func applySettings(from defaults: UserDefaults = .standard) {
        haptics.isEnabled = defaults.bool(forKey: AppSettings.hapticsEnabled)
        sound.isEnabled = defaults.bool(forKey: AppSettings.soundsEnabled)
    }

    /// Creates and stores a new session. A random seed for a normal run, the day's seed for the daily.
    @discardableResult
    func startRun(daily: Bool, now: Date = .now) -> GameSession {
        let dayKey = daily ? DailySeed.dayKey(for: now) : nil
        let seed = daily ? DailySeed.seed(forDayKey: dayKey!) : UInt64.random(in: .min ... .max)
        let session = GameSession(pack: pack, seed: seed, isDaily: daily, dailyKey: dayKey,
                                  haptics: haptics, sound: sound, history: history, startedAt: now)
        self.session = session
        session.start()
        return session
    }
}
```

Add `import SwiftData` at the top of `AppEnvironment.swift` (needed for `ModelContainer` in `preview()`).

- [ ] **Step 4: Implement the session**

`WatchGame/Game/GameSession.swift`:

```swift
import Foundation
import Observation
import SwipeSortEngine

/// Drives one run: owns the `RunState`, supplies it with time, and turns its effects
/// into view state, feedback and history writes.
@MainActor
@Observable
final class GameSession {
    enum Screen: Equatable {
        case roundIntro, playing, paused, results
    }

    struct ResolvedItem: Equatable {
        var item: ActiveItem
        var outcome: ItemOutcome
    }

    let pack: ContentPack
    let isDaily: Bool
    let dailyKey: String?
    let startedAt: Date

    private(set) var state: RunState
    /// The item on screen, nil during the inter-item gap and outside play.
    private(set) var activeItem: ActiveItem?
    /// The last resolved item, kept through the gap so views can animate its outcome.
    private(set) var resolvedItem: ResolvedItem?
    /// The last finished round, for the interstitial and the results screen.
    private(set) var lastRound: RoundResult?
    private(set) var summary: RunSummary?
    /// Whether `summary.score` beat every completed run recorded before this one.
    private(set) var isNewBest = false

    private let clock = ContinuousClock()
    private let epoch: ContinuousClock.Instant
    private var wakeTask: Task<Void, Never>?
    private let haptics: any HapticsService
    private let sound: any SoundService
    private let history: HistoryStore
    private let runEntry: RunEntry
    private let previousBest: Int?

    init(pack: ContentPack, seed: UInt64, isDaily: Bool, dailyKey: String?,
         configuration: RunConfiguration = .standard,
         haptics: any HapticsService, sound: any SoundService, history: HistoryStore,
         startedAt: Date = .now) {
        self.pack = pack
        self.isDaily = isDaily
        self.dailyKey = dailyKey
        self.startedAt = startedAt
        self.haptics = haptics
        self.sound = sound
        self.history = history
        state = RunState(pack: pack, configuration: configuration, seed: seed)
        epoch = clock.now
        previousBest = history.bestScore()
        runEntry = history.beginRun(packID: pack.id, isDaily: isDaily, dailyKey: dailyKey, seed: seed, startedAt: startedAt)
    }

    // MARK: - View state

    var screen: Screen {
        switch state.phase {
        case .notStarted, .roundIntro: .roundIntro
        case .playing, .betweenItems: .playing
        case .paused: .paused
        case .finished: .results
        }
    }

    var lives: Int { state.lives }
    var maximumLives: Int { state.configuration.maximumLives }
    var score: Int { state.score }
    var streak: Int { state.streak }
    var multiplier: Int { state.configuration.scoring.multiplier(streak: streak) }
    var roundNumber: Int { state.roundIndex + 1 }
    var roundCount: Int { state.plans.count }
    var currentPlan: RoundPlan { state.currentPlan }
    var roundDuration: Duration { state.configuration.roundDuration }
    var configuration: RunConfiguration { state.configuration }

    /// Time since the session started, on the same clock the engine sees.
    var now: Duration { clock.now - epoch }

    func roundTimeRemaining() -> Duration {
        state.roundTimeRemaining(at: now)
    }

    func dimensionName(for plan: RoundPlan) -> String {
        Localization.string(pack.dimension(id: plan.dimensionID)?.nameKey ?? plan.dimensionID)
    }

    func categoryLabel(_ categoryID: String, in plan: RoundPlan) -> String {
        let value = pack.dimension(id: plan.dimensionID)?.value(id: categoryID)
        return Localization.string(value?.labelKey ?? categoryID)
    }

    // MARK: - Player actions

    func start() { send(.startRun) }
    func startRound() { send(.startRound) }
    func answer(_ edge: Edge) { send(.answer(edge)) }

    func pause() {
        send(.pause)
        wakeTask?.cancel()
    }

    func resume() { send(.resume) }

    func quit() {
        wakeTask?.cancel()
        send(.quit)
    }

    /// Test hook: behaves as if the round clock ran out.
    func debugExpireRoundClock() {
        let effects = state.apply(.tick, at: now + roundDuration)
        handle(effects)
    }

    // MARK: - Engine plumbing

    private func send(_ event: RunEvent) {
        handle(state.apply(event, at: now))
    }

    private func handle(_ effects: [RunEffect]) {
        for effect in effects {
            switch effect {
            case .roundIntro:
                activeItem = nil
                resolvedItem = nil
            case .roundStarted:
                lastRound = nil
            case .itemShown(let item):
                activeItem = item
                resolvedItem = nil
            case .itemResolved(_, let outcome):
                if let item = activeItem {
                    resolvedItem = ResolvedItem(item: item, outcome: outcome)
                }
                activeItem = nil
            case .livesChanged, .scoreChanged:
                break
            case .roundEnded(let round):
                lastRound = round
                history.append(round, to: runEntry)
            case .runEnded(let summary):
                wakeTask?.cancel()
                activeItem = nil
                self.summary = summary
                isNewBest = summary.completed && summary.score > (previousBest ?? -1)
                history.finish(runEntry, summary: summary)
            case .feedback(let cue):
                haptics.play(cue)
                sound.play(cue)
            case .wake(let deadline):
                scheduleWake(at: deadline)
            }
        }
    }

    private func scheduleWake(at deadline: Duration) {
        wakeTask?.cancel()
        let instant = epoch + deadline
        wakeTask = Task { [weak self] in
            try? await Task.sleep(until: instant, clock: .continuous)
            guard !Task.isCancelled, let self else { return }
            self.send(.tick)
        }
    }
}
```

- [ ] **Step 5: Wire the environment into the app**

Replace `WatchGame/WatchGameApp.swift` with:

```swift
import SwiftUI

@main
struct WatchGameApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(environment)
        }
    }
}
```

Update the placeholder `HomeView` so its preview still compiles:

```swift
import SwiftUI
import SwipeSortEngine

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Text("Swipe Sort")
                    .font(.headline)
                Text("\(environment.pack.items.count) items ready")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    HomeView()
        .environment(AppEnvironment.preview())
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `Scripts/test.sh`
Expected: `TESTS OK`. The two sleeping tests take about three seconds together.

- [ ] **Step 7: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): game session driving the engine with a continuous clock"
```

### Task 15: Swipe classifier, item rendering and edge labels

**Files:**
- Create: `WatchGame/Views/Play/SwipeClassifier.swift`
- Create: `WatchGame/Views/Play/ItemView.swift`
- Create: `WatchGame/Views/Play/EdgeLabelsView.swift`
- Create: `WatchGameTests/SwipeClassifierTests.swift`

- [ ] **Step 1: Write the failing tests**

`WatchGameTests/SwipeClassifierTests.swift`:

```swift
import CoreGraphics
import Testing
import SwipeSortEngine
@testable import WatchGame

@Suite struct SwipeClassifierTests {
    let classifier = SwipeClassifier()
    let bounds = CGSize(width: 198, height: 242)
    let centre = CGPoint(x: 99, y: 121)

    func classify(_ dx: CGFloat, _ dy: CGFloat, predicted: CGSize? = nil, start: CGPoint? = nil) -> Edge? {
        classifier.edge(start: start ?? centre, translation: CGSize(width: dx, height: dy),
                        predictedTranslation: predicted ?? CGSize(width: dx, height: dy), bounds: bounds)
    }

    @Test func dominantAxisDecidesDirection() {
        #expect(classify(40, 5) == .right)
        #expect(classify(-40, 5) == .left)
        #expect(classify(5, -40) == .up)
        #expect(classify(5, 40) == .down)
    }

    @Test func shortDragIsIgnoredUnlessFlickPredictsFurther() {
        #expect(classify(10, 0) == nil)
        #expect(classify(10, 0, predicted: CGSize(width: 70, height: 0)) == .right)
        #expect(classify(10, 0, predicted: CGSize(width: 50, height: 0)) == nil)
    }

    @Test func diagonalWithinTwentyPercentIsAmbiguous() {
        #expect(classify(40, 36) == nil)
        #expect(classify(40, 30) == .right)
        #expect(classify(0, 0) == nil)
    }

    @Test func gesturesStartingNearAnEdgeAreIgnored() {
        #expect(classify(40, 0, start: CGPoint(x: 5, y: 121)) == nil)
        #expect(classify(40, 0, start: CGPoint(x: 99, y: 235)) == nil)
        #expect(classify(40, 0, start: CGPoint(x: 20, y: 121)) == .right)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/test.sh`
Expected: compile error for `SwipeClassifier`.

- [ ] **Step 3: Implement the classifier**

`WatchGame/Views/Play/SwipeClassifier.swift`:

```swift
import CoreGraphics
import SwipeSortEngine

/// Turns a finished drag into an edge, or nil when the gesture should be ignored (spec section 4).
struct SwipeClassifier {
    var minimumTranslation: CGFloat = 24
    var minimumPredictedTranslation: CGFloat = 60
    /// Minor axis over major axis above this ratio is "within 20 percent" and ambiguous.
    var ambiguityRatio: CGFloat = 0.8
    var edgeExclusion: CGFloat = 14

    func edge(start: CGPoint, translation: CGSize, predictedTranslation: CGSize, bounds: CGSize) -> Edge? {
        guard start.x >= edgeExclusion, start.y >= edgeExclusion,
              start.x <= bounds.width - edgeExclusion, start.y <= bounds.height - edgeExclusion
        else { return nil }

        let dx = translation.width
        let dy = translation.height
        let horizontal = abs(dx) >= abs(dy)
        let major = horizontal ? abs(dx) : abs(dy)
        let minor = horizontal ? abs(dy) : abs(dx)
        guard major > 0, minor / major <= ambiguityRatio else { return nil }

        let predictedMajor = horizontal ? abs(predictedTranslation.width) : abs(predictedTranslation.height)
        guard major >= minimumTranslation || predictedMajor >= minimumPredictedTranslation else { return nil }

        if horizontal {
            return dx > 0 ? .right : .left
        }
        return dy > 0 ? .down : .up
    }
}
```

- [ ] **Step 4: Implement item rendering**

`WatchGame/Views/Play/ItemView.swift`:

```swift
import SwiftUI
import SwipeSortEngine

/// Draws a pack item's visual at a given size, with an optional one-character hint overlay.
struct ItemView: View {
    var visual: Visual
    var hint: String?
    var size: CGFloat

    var body: some View {
        ZStack {
            switch visual {
            case let .shape(kind, colour):
                shape(kind)
                    .fill(Color(hex: colour))
                    .frame(width: size, height: size)
            case let .image(assetName):
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
            if let hint {
                Text(hint)
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black.opacity(0.75))
                    .accessibilityHidden(true)
            }
        }
    }

    private func shape(_ kind: ShapeKind) -> AnyShape {
        switch kind {
        case .circle: AnyShape(Circle())
        case .square: AnyShape(RoundedRectangle(cornerRadius: size * 0.12, style: .continuous))
        case .triangle: AnyShape(TriangleShape())
        case .star: AnyShape(StarShape())
        }
    }
}

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct StarShape: Shape {
    var points = 5

    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        var path = Path()
        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = Double(index) * .pi / Double(points) - .pi / 2
            let point = CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

extension Color {
    /// Parses "#RRGGBB" or "#RRGGBBAA". Falls back to grey for malformed input.
    init(hex: String) {
        var value: UInt64 = 0
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard Scanner(string: digits).scanHexInt64(&value), digits.count == 6 || digits.count == 8 else {
            self = .gray
            return
        }
        let alpha = digits.count == 8 ? Double(value & 0xFF) / 255 : 1
        let shift = digits.count == 8 ? 8 : 0
        self.init(
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            opacity: alpha
        )
    }
}

#Preview {
    HStack {
        ItemView(visual: .shape(kind: .star, colour: "#F0E442"), hint: "Y", size: 60)
        ItemView(visual: .shape(kind: .triangle, colour: "#0072B2"), hint: nil, size: 60)
    }
}
```

- [ ] **Step 5: Implement the edge labels**

`WatchGame/Views/Play/EdgeLabelsView.swift`:

```swift
import SwiftUI
import SwipeSortEngine

/// Category labels pinned to the active edges. When `tapToSort` is on each label is a
/// 44-point tap target; otherwise labels are decoration and swipes carry the input.
struct EdgeLabelsView: View {
    var labels: [Edge: String]
    var highlighted: Edge?
    var tapToSort: Bool
    var onTap: (Edge) -> Void

    var body: some View {
        ZStack {
            ForEach(Edge.allCases, id: \.self) { edge in
                if let text = labels[edge] {
                    label(text, edge: edge)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(for: edge))
                }
            }
        }
        .padding(4)
    }

    @ViewBuilder
    private func label(_ text: String, edge: Edge) -> some View {
        let core = Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(highlighted == edge ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.14)))
            .scaleEffect(highlighted == edge ? 1.12 : 1)
            .animation(.spring(duration: 0.25), value: highlighted == edge)
        if tapToSort {
            Button { onTap(edge) } label: { core.frame(minWidth: 44, minHeight: 44) }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Sort as \(text)"))
        } else {
            core.accessibilityHidden(true)
        }
    }

    private func alignment(for edge: Edge) -> Alignment {
        switch edge {
        case .up: .top
        case .down: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }
}

#Preview {
    EdgeLabelsView(labels: [.left: "Red", .right: "Blue", .up: "Green"], highlighted: .right, tapToSort: true) { _ in }
        .background(.black)
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `Scripts/test.sh`
Expected: `TESTS OK`.

- [ ] **Step 7: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): swipe classifier, item rendering and edge labels"
```

## Chunk 7: Play screens

### Task 16: Play screen, round intro, pause and the run container

**Files:**
- Create: `WatchGame/Views/Play/PlayView.swift`
- Create: `WatchGame/Views/Play/RoundIntroView.swift`
- Create: `WatchGame/Views/Play/PausedView.swift`
- Create: `WatchGame/Views/Play/ConfettiView.swift`
- Create: `WatchGame/Views/Play/RunView.swift`

- [ ] **Step 1: Implement the confetti burst**

`WatchGame/Views/Play/ConfettiView.swift`:

```swift
import SwiftUI

/// A one-second burst of at most 40 particles drawn with Canvas. Skipped under Reduce Motion.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let particles: [Particle] = (0..<40).map { _ in Particle() }
    private let start = Date()

    struct Particle {
        let angle = Double.random(in: 0 ..< 2 * .pi)
        let speed = Double.random(in: 60 ... 140)
        let size = Double.random(in: 3 ... 6)
        let hue = Double.random(in: 0 ... 1)
    }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation) { context in
                let t = min(context.date.timeIntervalSince(start), 1)
                Canvas { canvas, size in
                    let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                    for particle in particles {
                        let distance = particle.speed * t
                        let point = CGPoint(x: centre.x + cos(particle.angle) * distance,
                                            y: centre.y + sin(particle.angle) * distance + 40 * t * t)
                        let rect = CGRect(x: point.x, y: point.y, width: particle.size, height: particle.size)
                        canvas.fill(Path(ellipseIn: rect), with: .color(Color(hue: particle.hue, saturation: 0.8, brightness: 1).opacity(1 - t)))
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
```

- [ ] **Step 2: Implement the round intro**

`WatchGame/Views/Play/RoundIntroView.swift`:

```swift
import SwiftUI
import SwipeSortEngine

/// Shows the next rule and edge mapping, then auto-starts after 2.5 seconds or on tap.
/// The countdown stops while the scene is inactive or the display is dimmed.
struct RoundIntroView: View {
    let session: GameSession
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var countdownStart: Date?

    private let countdown: Duration = .milliseconds(2500)
    private var isActive: Bool { scenePhase == .active && !isLuminanceReduced }

    var body: some View {
        let plan = session.currentPlan
        ZStack {
            VStack(spacing: 6) {
                Text("Round \(session.roundNumber) of \(session.roundCount)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Sort by \(session.dimensionName(for: plan))")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                mappingPreview(plan)
                    .frame(height: 70)
                HStack(spacing: 12) {
                    LivesView(lives: session.lives, maximum: session.maximumLives)
                    Text(session.score, format: .number)
                        .font(.system(.footnote, design: .rounded).monospacedDigit())
                }
            }
            .padding(.horizontal, 8)
            if session.lastRound?.perfect == true {
                ConfettiView()
            }
            countdownRing
        }
        .contentShape(Rectangle())
        .onTapGesture { session.startRound() }
        .task(id: isActive) {
            guard isActive else { countdownStart = nil; return }
            countdownStart = Date()
            try? await Task.sleep(for: countdown)
            guard !Task.isCancelled, isActive, session.screen == .roundIntro else { return }
            session.startRound()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Double tap to start the round now"))
    }

    private var countdownRing: some View {
        TimelineView(.animation) { context in
            let elapsed = countdownStart.map { context.date.timeIntervalSince($0) } ?? 0
            let fraction = max(0, 1 - elapsed / (Double(countdown.components.seconds) + Double(countdown.components.attoseconds) / 1e18))
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(2)
        }
        .allowsHitTesting(false)
    }

    private func mappingPreview(_ plan: RoundPlan) -> some View {
        var labels: [Edge: String] = [:]
        for (edge, category) in plan.mapping.categoryByEdge {
            labels[edge] = session.categoryLabel(category, in: plan)
        }
        return EdgeLabelsView(labels: labels, highlighted: nil, tapToSort: false) { _ in }
            .scaleEffect(0.85)
    }
}

struct LivesView: View {
    var lives: Int
    var maximum: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maximum, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart")
                    .font(.system(size: 11))
                    .foregroundStyle(index < lives ? Color.red : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(lives) of \(maximum) lives"))
    }
}
```

- [ ] **Step 3: Implement the paused screen**

`WatchGame/Views/Play/PausedView.swift`:

```swift
import SwiftUI

struct PausedView: View {
    let session: GameSession
    var onQuit: () -> Void
    @State private var confirmingQuit = false

    var body: some View {
        VStack(spacing: 10) {
            Text("Paused")
                .font(.headline)
            Button {
                session.resume()
            } label: {
                Label("Resume", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .handGestureShortcut(.primaryAction)
            .buttonStyle(.borderedProminent)
            Button(role: .destructive) {
                confirmingQuit = true
            } label: {
                Label("Quit run", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .confirmationDialog("Quit this run?", isPresented: $confirmingQuit, titleVisibility: .visible) {
            Button("Quit", role: .destructive) {
                session.quit()
                onQuit()
            }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Finished rounds are kept. The run is marked incomplete.")
        }
    }
}
```

- [ ] **Step 4: Implement the play screen**

`WatchGame/Views/Play/PlayView.swift`:

```swift
import SwiftUI
import SwipeSortEngine

/// The playing state: round clock, lives and score, the item with its shrinking ring,
/// edge labels, swipe and tap input, and outcome animations.
struct PlayView: View {
    let session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @AppStorage(AppSettings.tapToSort) private var tapToSort = false
    @AppStorage(AppSettings.colourHints) private var colourHints = false

    private let classifier = SwipeClassifier()
    @State private var highlightedEdge: Edge?
    @State private var flashEdge = false

    var body: some View {
        GeometryReader { geometry in
            let bounds = geometry.size
            let itemSize = min(bounds.width, bounds.height) * 0.36
            ZStack {
                EdgeLabelsView(labels: labels, highlighted: highlightedEdge, tapToSort: tapToSort || voiceOver) { edge in
                    session.answer(edge)
                }
                itemLayer(itemSize: itemSize)
                hud
                if flashEdge {
                    Rectangle()
                        .stroke(Color.red.opacity(0.8), lineWidth: 6)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .allowsHitTesting(false)
                }
            }
            .frame(width: bounds.width, height: bounds.height)
            .contentShape(Rectangle())
            .gesture(swipe(bounds: bounds))
            .onChange(of: session.resolvedItem) { _, resolved in
                animateOutcome(resolved)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Layers

    private var hud: some View {
        VStack {
            TimelineView(.animation(minimumInterval: 0.1)) { _ in
                let remaining = session.roundTimeRemaining()
                let fraction = max(0, min(1, remaining / session.roundDuration))
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: proxy.size.width * fraction, height: 3)
                }
                .frame(height: 3)
                .accessibilityHidden(true)
            }
            HStack {
                LivesView(lives: session.lives, maximum: session.maximumLives)
                Spacer()
                if session.multiplier > 1 {
                    Text("\(session.multiplier)x")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.accentColor))
                        .transition(.scale.combined(with: .opacity))
                        .id(session.multiplier)
                }
                Text(session.score, format: .number)
                    .font(.system(.footnote, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("Score \(session.score)"))
            }
            .padding(.horizontal, 6)
            .animation(.spring(duration: 0.3), value: session.multiplier)
            .animation(.default, value: session.score)
            Spacer()
            Button {
                session.pause()
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 11))
                    .frame(width: 30, height: 22)
            }
            .buttonStyle(.plain)
            .handGestureShortcut(.primaryAction)
            .accessibilityLabel(Text("Pause"))
            .padding(.bottom, 2)
        }
    }

    @ViewBuilder
    private func itemLayer(itemSize: CGFloat) -> some View {
        if let active = session.activeItem {
            ZStack {
                timerRing(for: active, size: itemSize + 18)
                ItemView(visual: active.item.visual, hint: hint(for: active.item), size: itemSize)
            }
            .id(active.index)
            .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(session.categoryLabel(active.expectedCategoryID, in: session.currentPlan)))
            .accessibilityActions {
                ForEach(session.currentPlan.mapping.edges, id: \.self) { edge in
                    Button(labels[edge] ?? edge.rawValue) { session.answer(edge) }
                }
            }
        } else if let resolved = session.resolvedItem {
            OutcomeItemView(resolved: resolved, hint: hint(for: resolved.item.item), size: itemSize, reduceMotion: reduceMotion)
                .id(-1 - resolved.item.index)
                .accessibilityHidden(true)
        }
    }

    private func timerRing(for active: ActiveItem, size: CGFloat) -> some View {
        TimelineView(.animation) { _ in
            let remaining = max(.zero, active.deadline - session.now)
            let fraction = remaining / active.window
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(fraction < 0.3 ? Color.red : Color.white.opacity(0.7), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Input

    private var labels: [Edge: String] {
        var result: [Edge: String] = [:]
        for (edge, category) in session.currentPlan.mapping.categoryByEdge {
            result[edge] = session.categoryLabel(category, in: session.currentPlan)
        }
        return result
    }

    private func hint(for item: Item) -> String? {
        guard colourHints else { return nil }
        for dimension in session.pack.dimensions {
            if let valueID = item.attributes[dimension.id],
               let hintKey = dimension.value(id: valueID)?.hintKey {
                return Localization.string(hintKey)
            }
        }
        return nil
    }

    private func swipe(bounds: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onEnded { value in
                guard session.activeItem != nil,
                      let edge = classifier.edge(start: value.startLocation, translation: value.translation,
                                                 predictedTranslation: value.predictedEndTranslation, bounds: bounds)
                else { return }
                session.answer(edge)
            }
    }

    // MARK: - Outcome animation

    private func animateOutcome(_ resolved: GameSession.ResolvedItem?) {
        guard let resolved else { return }
        switch resolved.outcome {
        case .correct:
            highlightedEdge = resolved.item.expectedEdge
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                highlightedEdge = nil
            }
        case .wrong, .timedOut:
            withAnimation(.easeOut(duration: 0.1)) { flashEdge = true }
            Task {
                try? await Task.sleep(for: .milliseconds(180))
                withAnimation(.easeIn(duration: 0.15)) { flashEdge = false }
            }
        }
    }
}

/// The just-resolved item during the inter-item gap: flies off, shakes, or dissolves.
private struct OutcomeItemView: View {
    let resolved: GameSession.ResolvedItem
    let hint: String?
    let size: CGFloat
    let reduceMotion: Bool
    @State private var progress: CGFloat = 0

    var body: some View {
        ItemView(visual: resolved.item.item.visual, hint: hint, size: size)
            .modifier(outcomeModifier)
            .onAppear {
                withAnimation(.easeIn(duration: 0.22)) { progress = 1 }
            }
    }

    private var outcomeModifier: some ViewModifier {
        switch resolved.outcome {
        case .correct:
            let edge = resolved.item.expectedEdge
            let distance: CGFloat = reduceMotion ? 0 : 90 * progress
            return OutcomeModifier(
                offset: CGSize(width: edge == .left ? -distance : edge == .right ? distance : 0,
                               height: edge == .up ? -distance : edge == .down ? distance : 0),
                scale: reduceMotion ? 1 : 1 + 0.15 * progress,
                opacity: 1 - progress
            )
        case .wrong:
            let shake: CGFloat = reduceMotion ? 0 : sin(progress * .pi * 4) * 8 * (1 - progress)
            return OutcomeModifier(offset: CGSize(width: shake, height: 0), scale: 1, opacity: 1 - progress * 0.6)
        case .timedOut:
            return OutcomeModifier(offset: .zero, scale: reduceMotion ? 1 : 1 - 0.2 * progress, opacity: 1 - progress)
        }
    }
}

private struct OutcomeModifier: ViewModifier, Animatable {
    var offset: CGSize
    var scale: CGFloat
    var opacity: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .offset(offset)
            .opacity(opacity)
    }
}
```

- [ ] **Step 5: Implement the run container**

`WatchGame/Views/Play/RunView.swift`:

```swift
import SwiftUI

/// Full-screen host for a run. Switches between intro, play, pause and results,
/// and pauses play whenever the scene is not active or the display is dimmed.
struct RunView: View {
    let session: GameSession
    var onPlayAgain: () -> Void
    var onDismiss: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced

    var body: some View {
        Group {
            switch session.screen {
            case .roundIntro:
                RoundIntroView(session: session)
            case .playing:
                PlayView(session: session)
            case .paused:
                PausedView(session: session, onQuit: onDismiss)
            case .results:
                if let summary = session.summary, summary.completed {
                    ResultsView(
                        data: ResultsData(summary: summary, isDaily: session.isDaily, isNewBest: session.isNewBest),
                        onPlayAgain: onPlayAgain,
                        onHome: onDismiss
                    )
                } else {
                    Color.clear.onAppear(perform: onDismiss)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pauseIfPlaying() }
        }
        .onChange(of: isLuminanceReduced) { _, reduced in
            if reduced { pauseIfPlaying() }
        }
    }

    private func pauseIfPlaying() {
        if session.screen == .playing {
            session.pause()
        }
    }
}
```

`ResultsView` and `ResultsData` are created in Task 17; until then add a temporary stub file `WatchGame/Views/Results/ResultsView.swift` containing only:

```swift
import SwiftUI
import SwipeSortEngine

struct ResultsData {
    var summary: RunSummary
    var isDaily: Bool
    var isNewBest: Bool
}

struct ResultsView: View {
    var data: ResultsData
    var onPlayAgain: () -> Void
    var onHome: () -> Void

    var body: some View {
        VStack {
            Text(data.summary.score, format: .number).font(.title2)
            Button("Home", action: onHome)
        }
    }
}
```

- [ ] **Step 6: Build**

Run: `Scripts/build.sh`
Expected: `BUILD OK`. Fix any compile errors in place; the most likely are missing `import SwipeSortEngine` lines and Duration arithmetic in `remaining / session.roundDuration` (both are `Duration`, which divides to `Double`).

- [ ] **Step 7: Run the tests**

Run: `Scripts/test.sh`
Expected: `TESTS OK`.

- [ ] **Step 8: Commit**

```bash
git add WatchGame
git commit -m "feat(app): play screen with swipe input, round intro, pause and outcome animations"
```

### Task 17: Results screen

**Files:**
- Modify: `WatchGame/Views/Results/ResultsView.swift` (replace the stub)
- Create: `WatchGame/Views/Results/StatisticsSections.swift`
- Create: `WatchGame/Game/DurationFormatting.swift`
- Create: `WatchGameTests/DurationFormattingTests.swift`

- [ ] **Step 1: Write the failing test**

`WatchGameTests/DurationFormattingTests.swift`:

```swift
import Testing
@testable import WatchGame

@Suite struct DurationFormattingTests {
    @Test func secondsWithTwoDecimals() {
        #expect(Duration.milliseconds(482).secondsText == "0.48 s")
        #expect(Duration.milliseconds(1250).secondsText == "1.25 s")
        #expect(Duration.zero.secondsText == "0.00 s")
    }

    @Test func signedMillisecondsForSwitchCost() {
        #expect(Duration.milliseconds(180).signedMillisecondsText == "+180 ms")
        #expect(Duration.milliseconds(-40).signedMillisecondsText == "-40 ms")
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/test.sh`
Expected: compile error, `secondsText` not found.

- [ ] **Step 3: Implement formatting**

`WatchGame/Game/DurationFormatting.swift`:

```swift
import Foundation

extension Duration {
    var seconds: Double { self / .seconds(1) }

    /// "0.48 s"
    var secondsText: String {
        String(format: "%.2f s", seconds)
    }

    /// "+180 ms" or "-40 ms"
    var signedMillisecondsText: String {
        let milliseconds = Int((self / .milliseconds(1)).rounded())
        return String(format: "%+d ms", milliseconds)
    }
}
```

- [ ] **Step 4: Implement the statistics sections**

`WatchGame/Views/Results/StatisticsSections.swift`:

```swift
import SwiftUI
import SwipeSortEngine

/// The section 3.6 breakdown, shared by the results screen and history detail.
struct StatisticsSections: View {
    var statistics: RunStatistics
    var pack: ContentPack
    var rounds: [RoundResult]

    var body: some View {
        Section("Errors") {
            row("Wrong swipes", value: "\(statistics.wrongSwipeCount)")
            row("Timeouts", value: "\(statistics.timeoutCount)")
            ForEach(statistics.errorsByDimension, id: \.dimensionID) { entry in
                row(dimensionName(entry.dimensionID), value: "\(entry.errors) of \(entry.total)")
            }
        }
        if !statistics.confusionPairs.isEmpty {
            Section("Mixed up") {
                ForEach(statistics.confusionPairs.prefix(3), id: \.self) { pair in
                    HStack {
                        Text("\(categoryLabel(pair.expectedCategoryID)) as \(categoryLabel(pair.answeredCategoryID))")
                            .lineLimit(2)
                        Spacer()
                        Text("\(pair.count)x")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
            }
        }
        Section("Speed") {
            row("Reaction", value: statistics.meanReaction?.secondsText ?? "–")
            row("Switch cost", value: statistics.switchCost?.signedMillisecondsText ?? "–")
        }
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.footnote)
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.footnote)
    }

    private func dimensionName(_ id: String) -> String {
        Localization.string(pack.dimension(id: id)?.nameKey ?? id)
    }

    private func categoryLabel(_ id: String) -> String {
        for dimension in pack.dimensions {
            if let value = dimension.value(id: id) {
                return Localization.string(value.labelKey)
            }
        }
        return id
    }
}

extension ConfusionPair: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(expectedCategoryID)
        hasher.combine(answeredCategoryID)
        hasher.combine(count)
    }
}
```

If the `@retroactive` conformance produces a warning about `Equatable` already existing, instead add `Hashable` to `ConfusionPair` in the engine (`Packages/SwipeSortEngine/Sources/SwipeSortEngine/RunStatistics.swift`) and delete the extension here.

- [ ] **Step 5: Implement the results screen**

Replace `WatchGame/Views/Results/ResultsView.swift` with:

```swift
import SwiftUI
import SwipeSortEngine

struct ResultsData {
    var summary: RunSummary
    var isDaily: Bool
    var isNewBest: Bool
    var pack: ContentPack = .shapesAndColours

    var statistics: RunStatistics { RunStatistics.compute(rounds: summary.rounds) }
}

/// Final score with the error breakdown. Also used by History for past runs.
struct ResultsView: View {
    var data: ResultsData
    var onPlayAgain: (() -> Void)?
    var onHome: (() -> Void)?

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    if data.isDaily {
                        Text("Daily challenge")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(data.summary.score, format: .number)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                    if data.isNewBest {
                        Label("New best", systemImage: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                    HStack(spacing: 10) {
                        stat("Accuracy", data.statistics.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "–")
                        stat("Rounds", "\(data.summary.roundsCompleted) of \(data.summary.rounds.count)")
                        stat("Lives", "\(data.summary.livesRemaining)")
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .overlay {
                    if data.summary.rounds.last?.perfect == true {
                        ConfettiView()
                    }
                }
            }
            StatisticsSections(statistics: data.statistics, pack: data.pack, rounds: data.summary.rounds)
            if onPlayAgain != nil || onHome != nil {
                Section {
                    if let onPlayAgain {
                        Button("Play again", action: onPlayAgain)
                            .buttonStyle(.borderedProminent)
                    }
                    if let onHome {
                        Button("Home", action: onHome)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(onHome == nil ? "Run" : "Results")
    }

    private func stat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let rounds = (0..<8).map { index in
        RoundResult(index: index, dimensionID: index.isMultiple(of: 2) ? "colour" : "shape", categoryCount: 3, perfect: index == 7, cutShort: false, score: 900, items: [
            ItemResult(roundIndex: index, itemIndex: 0, dimensionID: "colour", attributes: [:], expectedCategoryID: "red", answeredCategoryID: "blue", correct: false, timedOut: false, reaction: .milliseconds(600), window: .seconds(2), points: 0),
            ItemResult(roundIndex: index, itemIndex: 1, dimensionID: "colour", attributes: [:], expectedCategoryID: "red", answeredCategoryID: "red", correct: true, timedOut: false, reaction: .milliseconds(450), window: .seconds(2), points: 138),
        ])
    }
    let summary = RunSummary(seed: 1, packID: "shapes-colours", score: 7200, livesRemaining: 2, endReason: .completedAllRounds, rounds: rounds)
    NavigationStack {
        ResultsView(data: ResultsData(summary: summary, isDaily: true, isNewBest: true), onPlayAgain: {}, onHome: {})
    }
}
```

- [ ] **Step 6: Build and test**

Run: `Scripts/build.sh` then `Scripts/test.sh`
Expected: `BUILD OK`, `TESTS OK`.

- [ ] **Step 7: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): results screen with error breakdown and switch cost"
```

## Chunk 8: Home, history and settings

### Task 18: Home, run presentation, daily challenge and settings

**Files:**
- Modify: `WatchGame/Views/Home/HomeView.swift` (replace the placeholder)
- Create: `WatchGame/Views/Settings/SettingsView.swift`
- Create: `WatchGame/Game/LaunchRequests.swift`
- Create: `WatchGameTests/LaunchRequestsTests.swift`

- [ ] **Step 1: Write the failing test**

`WatchGameTests/LaunchRequestsTests.swift`:

```swift
import Testing
@testable import WatchGame

@MainActor
@Suite struct LaunchRequestsTests {
    @Test func dailyRequestIsConsumedOnce() {
        let requests = LaunchRequests()
        #expect(!requests.takeDailyRequest())
        requests.requestDaily()
        #expect(requests.takeDailyRequest())
        #expect(!requests.takeDailyRequest())
    }

    @Test func dailyURLIsRecognised() {
        #expect(LaunchRequests.isDailyURL(URL(string: "swipesort://daily")!))
        #expect(!LaunchRequests.isDailyURL(URL(string: "swipesort://history")!))
        #expect(!LaunchRequests.isDailyURL(URL(string: "https://example.com/daily")!))
    }
}
```

Add `import Foundation` at the top of that test file.

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/test.sh`
Expected: compile error for `LaunchRequests`.

- [ ] **Step 3: Implement launch requests**

`WatchGame/Game/LaunchRequests.swift`:

```swift
import Foundation
import Observation

/// Requests that arrive from outside the UI (the widget deep link, the App Intent)
/// and are consumed by Home when it is safe to start a run.
@MainActor
@Observable
final class LaunchRequests {
    static let shared = LaunchRequests()

    private(set) var dailyRequested = false

    func requestDaily() {
        dailyRequested = true
    }

    /// Returns true once per request, then clears it.
    func takeDailyRequest() -> Bool {
        defer { dailyRequested = false }
        return dailyRequested
    }

    static func isDailyURL(_ url: URL) -> Bool {
        url.scheme == "swipesort" && url.host() == "daily"
    }
}
```

- [ ] **Step 4: Implement Home**

Replace `WatchGame/Views/Home/HomeView.swift` with:

```swift
import SwiftUI
import SwipeSortEngine

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var isRunPresented = false
    @State private var launchRequests = LaunchRequests.shared

    private var todayKey: String { DailySeed.dayKey(for: .now) }

    var body: some View {
        @Bindable var environment = environment
        NavigationStack {
            List {
                Section {
                    Button {
                        startRun(daily: false)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)

                    Button {
                        startRun(daily: true)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Label("Daily challenge", systemImage: "calendar")
                            Text(dailyStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("History", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Swipe Sort")
        }
        .fullScreenCover(isPresented: $isRunPresented) {
            if let session = environment.session {
                RunView(
                    session: session,
                    onPlayAgain: { startRun(daily: session.isDaily) },
                    onDismiss: dismissRun
                )
                .id(ObjectIdentifier(session))
            }
        }
        .onOpenURL { url in
            if LaunchRequests.isDailyURL(url) {
                launchRequests.requestDaily()
                consumeRequests()
            }
        }
        .onAppear(perform: consumeRequests)
        .onChange(of: launchRequests.dailyRequested) { _, _ in consumeRequests() }
    }

    private var dailyStatus: String {
        let streak = environment.history.dailyStreak()
        let played = environment.history.hasCompletedDaily(dayKey: todayKey)
        let streakText = streak == 1 ? String(localized: "1 day streak") : String(localized: "\(streak) day streak")
        return played ? String(localized: "Done today · \(streakText)") : streakText
    }

    private func startRun(daily: Bool) {
        environment.applySettings()
        environment.startRun(daily: daily)
        isRunPresented = true
    }

    private func dismissRun() {
        isRunPresented = false
        environment.session = nil
    }

    /// Starts the daily if the widget or an intent asked for it and no run is in progress.
    private func consumeRequests() {
        guard launchRequests.dailyRequested else { return }
        if environment.session != nil, isRunPresented {
            _ = launchRequests.takeDailyRequest()
            return
        }
        if launchRequests.takeDailyRequest() {
            startRun(daily: true)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppEnvironment.preview())
}
```

- [ ] **Step 5: Implement Settings**

`WatchGame/Views/Settings/SettingsView.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage(AppSettings.soundsEnabled) private var soundsEnabled = true
    @AppStorage(AppSettings.hapticsEnabled) private var hapticsEnabled = true
    @AppStorage(AppSettings.tapToSort) private var tapToSort = false
    @AppStorage(AppSettings.colourHints) private var colourHints = false
    @State private var confirmingReset = false

    var body: some View {
        List {
            Section("Feedback") {
                Toggle("Sounds", isOn: $soundsEnabled)
                Toggle("Haptics", isOn: $hapticsEnabled)
            }
            Section {
                Toggle("Tap to sort", isOn: $tapToSort)
                Toggle("Colour hints", isOn: $colourHints)
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Tap to sort lets you tap an edge label instead of swiping. Colour hints add a letter to each colour.")
            }
            Section {
                Button("Reset history", role: .destructive) {
                    confirmingReset = true
                }
            }
            Section("About") {
                LabeledContent("Version", value: Self.versionText)
                if environment.history.isFallback {
                    Text("History is unavailable on this watch right now. Scores are kept for this session only.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .onChange(of: soundsEnabled) { _, _ in environment.applySettings() }
        .onChange(of: hapticsEnabled) { _, _ in environment.applySettings() }
        .confirmationDialog("Reset all history?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                environment.history.reset()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every run, best score and daily streak will be deleted. This cannot be undone.")
        }
    }

    static var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AppEnvironment.preview())
    }
}
```

`HistoryView` does not exist until Task 19. Create a temporary stub `WatchGame/Views/History/HistoryView.swift`:

```swift
import SwiftUI

struct HistoryView: View {
    var body: some View {
        Text("History")
    }
}
```

- [ ] **Step 6: Build and test**

Run: `Scripts/build.sh` then `Scripts/test.sh`
Expected: `BUILD OK`, `TESTS OK`.

- [ ] **Step 7: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): home screen, run presentation, daily challenge and settings"
```

### Task 19: History summary and screen

**Files:**
- Create: `WatchGame/Persistence/HistorySummary.swift`
- Modify: `WatchGame/Views/History/HistoryView.swift` (replace the stub)
- Create: `WatchGameTests/HistorySummaryTests.swift`

- [ ] **Step 1: Write the failing tests**

`WatchGameTests/HistorySummaryTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
import SwipeSortEngine
@testable import WatchGame

@MainActor
@Suite struct HistorySummaryTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func makeStore() throws -> HistoryStore {
        let container = try ModelContainer(for: HistoryStore.schema, configurations: ModelConfiguration(schema: HistoryStore.schema, isStoredInMemoryOnly: true))
        return HistoryStore(container: container)
    }

    func date(day: Int, hour: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func round(reactionMilliseconds: Int) -> RoundResult {
        let items = (0..<6).map { index in
            ItemResult(roundIndex: 0, itemIndex: index, dimensionID: "colour", attributes: [:], expectedCategoryID: "red",
                       answeredCategoryID: "red", correct: true, timedOut: false,
                       reaction: .milliseconds(reactionMilliseconds), window: .seconds(2), points: 100)
        }
        return RoundResult(index: 0, dimensionID: "colour", categoryCount: 2, perfect: true, cutShort: false, score: 600, items: items)
    }

    @discardableResult
    func play(_ store: HistoryStore, day: Int, hour: Int, score: Int, reactionMilliseconds: Int, completed: Bool = true) -> RunEntry {
        let started = date(day: day, hour: hour)
        let run = store.beginRun(packID: "p", isDaily: false, dailyKey: nil, seed: 1, startedAt: started)
        let round = round(reactionMilliseconds: reactionMilliseconds)
        store.append(round, to: run)
        store.finish(run, summary: RunSummary(seed: 1, packID: "p", score: score, livesRemaining: 3,
                                              endReason: completed ? .completedAllRounds : .quit, rounds: [round]),
                     endedAt: started.addingTimeInterval(400))
        return run
    }

    @Test func timeOfDayBuckets() {
        #expect(HistorySummary.TimeOfDay.bucket(hour: 5) == .morning)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 11) == .morning)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 12) == .afternoon)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 16) == .afternoon)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 17) == .evening)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 21) == .evening)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 22) == .night)
        #expect(HistorySummary.TimeOfDay.bucket(hour: 4) == .night)
    }

    @Test func tilesAndPointsUseCompletedRunsOldestFirst() throws {
        let store = try makeStore()
        play(store, day: 1, hour: 9, score: 500, reactionMilliseconds: 600)
        play(store, day: 2, hour: 9, score: 900, reactionMilliseconds: 500)
        play(store, day: 3, hour: 9, score: 5000, reactionMilliseconds: 100, completed: false)
        let summary = HistorySummary.make(store: store, calendar: calendar)
        #expect(summary.bestScore == 900)
        #expect(summary.runsPlayed == 2)
        #expect(summary.points.map(\.score) == [500, 900])
        #expect(summary.points.map(\.reactionSeconds) == [0.6, 0.5])
        #expect(summary.points.first?.index == 1)
    }

    @Test func sharpestTimeNeedsThreeRunsPerBucket() throws {
        let store = try makeStore()
        play(store, day: 1, hour: 8, score: 1, reactionMilliseconds: 400)
        play(store, day: 2, hour: 8, score: 1, reactionMilliseconds: 400)
        play(store, day: 3, hour: 20, score: 1, reactionMilliseconds: 300)
        play(store, day: 4, hour: 20, score: 1, reactionMilliseconds: 300)
        #expect(HistorySummary.make(store: store, calendar: calendar).sharpestTimeOfDay == nil)
        play(store, day: 5, hour: 8, score: 1, reactionMilliseconds: 400)
        #expect(HistorySummary.make(store: store, calendar: calendar).sharpestTimeOfDay == .morning)
        play(store, day: 6, hour: 20, score: 1, reactionMilliseconds: 300)
        #expect(HistorySummary.make(store: store, calendar: calendar).sharpestTimeOfDay == .evening)
    }

    @Test func pointsAreLimitedToThirtyMostRecent() throws {
        let store = try makeStore()
        for day in 1...35 {
            play(store, day: min(day, 30), hour: day % 24, score: day, reactionMilliseconds: 500)
        }
        let summary = HistorySummary.make(store: store, calendar: calendar)
        #expect(summary.points.count == 30)
        #expect(summary.runsPlayed == 35)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `Scripts/test.sh`
Expected: compile error for `HistorySummary`.

- [ ] **Step 3: Implement the summary**

`WatchGame/Persistence/HistorySummary.swift`:

```swift
import Foundation
import SwipeSortEngine

/// Everything the History screen shows, computed from completed runs only.
struct HistorySummary {
    struct Point: Identifiable, Equatable {
        let id: UUID
        /// 1-based position among the plotted runs, oldest first.
        let index: Int
        let date: Date
        let score: Int
        let reactionSeconds: Double?
        let switchCostMilliseconds: Double?
    }

    enum TimeOfDay: String, CaseIterable {
        case morning, afternoon, evening, night

        static func bucket(hour: Int) -> TimeOfDay {
            switch hour {
            case 5...11: .morning
            case 12...16: .afternoon
            case 17...21: .evening
            default: .night
            }
        }

        var title: String {
            switch self {
            case .morning: String(localized: "Morning")
            case .afternoon: String(localized: "Afternoon")
            case .evening: String(localized: "Evening")
            case .night: String(localized: "Night")
            }
        }
    }

    var bestScore: Int?
    var runsPlayed: Int
    var dailyStreak: Int
    var points: [Point]
    var sharpestTimeOfDay: TimeOfDay?
    var recentRuns: [RunEntry]

    static let chartLimit = 30
    static let minimumRunsPerBucket = 3

    @MainActor
    static func make(store: HistoryStore, calendar: Calendar = .current, now: Date = .now) -> HistorySummary {
        let completed = store.completedRuns()
        let plotted = Array(completed.prefix(chartLimit)).reversed()
        let points = plotted.enumerated().map { offset, run -> Point in
            let statistics = RunStatistics.compute(rounds: run.roundResults)
            return Point(
                id: run.id,
                index: offset + 1,
                date: run.startedAt,
                score: run.score,
                reactionSeconds: statistics.meanReaction?.seconds,
                switchCostMilliseconds: statistics.switchCost.map { $0 / .milliseconds(1) }
            )
        }

        var reactionsByBucket: [TimeOfDay: [Double]] = [:]
        for run in completed {
            guard let reaction = RunStatistics.compute(rounds: run.roundResults).meanReaction?.seconds else { continue }
            let hour = calendar.component(.hour, from: run.startedAt)
            reactionsByBucket[TimeOfDay.bucket(hour: hour), default: []].append(reaction)
        }
        let sharpest = reactionsByBucket
            .filter { $0.value.count >= minimumRunsPerBucket }
            .map { (bucket: $0.key, mean: $0.value.reduce(0, +) / Double($0.value.count)) }
            .min { $0.mean < $1.mean }?
            .bucket

        return HistorySummary(
            bestScore: completed.map(\.score).max(),
            runsPlayed: completed.count,
            dailyStreak: store.dailyStreak(today: now, calendar: calendar),
            points: points,
            sharpestTimeOfDay: sharpest,
            recentRuns: store.allRuns(limit: chartLimit)
        )
    }
}
```

- [ ] **Step 4: Implement the History screen**

Replace `WatchGame/Views/History/HistoryView.swift` with:

```swift
import Charts
import SwiftUI
import SwipeSortEngine

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var summary: HistorySummary?

    var body: some View {
        List {
            if environment.history.isFallback {
                Section {
                    Text("History is unavailable on this watch right now.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            if let summary {
                Section {
                    HStack {
                        tile("Best", summary.bestScore.map { "\($0)" } ?? "–")
                        tile("Runs", "\(summary.runsPlayed)")
                        tile("Streak", "\(summary.dailyStreak)")
                    }
                    .listRowBackground(Color.clear)
                }
                if summary.points.count >= 2 {
                    Section("Score") {
                        chart(summary.points, value: { Double($0.score) })
                    }
                    Section("Reaction time") {
                        chart(summary.points.filter { $0.reactionSeconds != nil }, value: { $0.reactionSeconds ?? 0 })
                    }
                    Section("Switch cost") {
                        chart(summary.points.filter { $0.switchCostMilliseconds != nil }, value: { $0.switchCostMilliseconds ?? 0 })
                    }
                }
                if let sharpest = summary.sharpestTimeOfDay {
                    Section {
                        LabeledContent("Sharpest", value: sharpest.title)
                    }
                }
                Section("Runs") {
                    if summary.recentRuns.isEmpty {
                        Text("Play a run to see it here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(summary.recentRuns, id: \.id) { run in
                        NavigationLink {
                            ResultsView(data: ResultsData(
                                summary: runSummary(run),
                                isDaily: run.isDaily,
                                isNewBest: false,
                                pack: environment.packs.first { $0.id == run.packID } ?? environment.pack
                            ))
                        } label: {
                            runRow(run)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .task { summary = HistorySummary.make(store: environment.history) }
    }

    private func tile(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func chart(_ points: [HistorySummary.Point], value: @escaping (HistorySummary.Point) -> Double) -> some View {
        Chart(points) { point in
            LineMark(x: .value("Run", point.index), y: .value("Value", value(point)))
                .interpolationMethod(.monotone)
            PointMark(x: .value("Run", point.index), y: .value("Value", value(point)))
                .symbolSize(10)
        }
        .chartXAxis(.hidden)
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
        .frame(height: 70)
        .accessibilityLabel(Text("Trend over the last \(points.count) runs"))
    }

    private func runRow(_ run: RunEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(run.startedAt, format: .dateTime.day().month().hour().minute())
                    .font(.footnote)
                HStack(spacing: 4) {
                    if run.isDaily {
                        Image(systemName: "calendar").font(.system(size: 9))
                    }
                    Text(run.completed ? "\(run.roundsCompleted) rounds" : "Incomplete")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(run.score, format: .number)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(run.completed ? .primary : .secondary)
        }
    }

    private func runSummary(_ run: RunEntry) -> RunSummary {
        RunSummary(seed: UInt64(bitPattern: run.seed), packID: run.packID, score: run.score,
                   livesRemaining: run.livesRemaining, endReason: run.endReason, rounds: run.roundResults)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
            .environment(AppEnvironment.preview())
    }
}
```

`ResultsView` shows the sections for any `RunSummary`, including incomplete ones, because `ResultsData` does not check `completed`; History passes the run's actual end reason so the title and rounds count read correctly.

- [ ] **Step 5: Build and test**

Run: `Scripts/build.sh` then `Scripts/test.sh`
Expected: `BUILD OK`, `TESTS OK`.

- [ ] **Step 6: Commit**

```bash
git add WatchGame WatchGameTests
git commit -m "feat(app): history summary with charts, sharpest time of day and run list"
```

### Task 20: Accessibility and layout pass on every watch size

**Files:**
- Create: `Scripts/screenshots.sh`
- Create: `docs/screenshots/` (generated PNGs, committed)
- Modify: any view that fails the checks below

- [ ] **Step 1: Write the screenshot script**

`Scripts/screenshots.sh`:

```bash
#!/bin/zsh
# Builds once, then installs and screenshots the app on every watch size in the simulator.
set -euo pipefail
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."
OUT=docs/screenshots
mkdir -p "$OUT"
DEVICES=("Apple Watch Series 9 (41mm)" "Apple Watch Series 11 (42mm)" "Apple Watch SE 3 (44mm)" "Apple Watch Series 9 (45mm)" "Apple Watch Series 11 (46mm)" "Apple Watch Ultra 3 (49mm)")
xcodebuild -project WatchGame.xcodeproj -scheme WatchGame -destination 'generic/platform=watchOS Simulator' \
  -derivedDataPath .build/DerivedData -quiet CODE_SIGNING_ALLOWED=NO build
APP=.build/DerivedData/Build/Products/Debug-watchsimulator/WatchGame.app
for device in "${DEVICES[@]}"; do
  udid=$(xcrun simctl list devices available | grep "$device (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  if [ -z "$udid" ]; then echo "skip: $device not available"; continue; fi
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl install "$udid" "$APP"
  xcrun simctl launch "$udid" com.pynto.swipesort.watchkitapp >/dev/null
  sleep 3
  slug=$(echo "$device" | tr -cd '[:alnum:]' )
  xcrun simctl io "$udid" screenshot "$OUT/$slug-home.png" >/dev/null
  echo "captured $OUT/$slug-home.png"
  xcrun simctl shutdown "$udid" >/dev/null || true
done
```

Run `chmod +x Scripts/screenshots.sh` then `Scripts/screenshots.sh`. Any device name that does not exist in this simulator set is skipped; create missing ones with `xcrun simctl create "<name>" "<device type id>" "<watchOS runtime id>"` using ids from `xcrun simctl list devicetypes` and `xcrun simctl list runtimes`.

- [ ] **Step 2: Check the play screen on the smallest and largest sizes**

On the 41mm and 49mm simulators: launch the app, start a run, and confirm with a screenshot (`xcrun simctl io booted screenshot play.png`) that all four edge labels are legible, do not overlap the item or its ring, and with Tap to sort on each label is at least 44 points tall. If labels overlap on 41mm, reduce `itemSize` multiplier in `PlayView` from 0.36 to 0.32 and the label font from 13 to 12 for widths under 180 points using `@Environment(\.horizontalSizeClass)` is not available on watchOS, so use the `GeometryReader` width already in `PlayView`.

- [ ] **Step 3: Accessibility checks**

With the Accessibility Inspector target set to the booted simulator (Xcode menu Open Developer Tool, Accessibility Inspector) or by reading labels with `xcrun simctl` unavailable, verify by code review and the Inspector:
- Every button on Home, Settings, Paused and Results has a label that reads as an action.
- The play item announces its category (Task 16 sets `accessibilityLabel`) and exposes one custom action per active edge.
- Edge labels are hidden from VoiceOver when tap to sort is off and become buttons when it is on.
- `LivesView` announces "n of 3 lives".
- Reduce Motion: enable it in the simulator (Settings, Accessibility, Motion) and confirm the item crossfades rather than flies, and no confetti appears after a perfect round.

Fix any gap in the relevant view and re-run `Scripts/test.sh`.

- [ ] **Step 4: Commit**

```bash
git add Scripts docs/screenshots WatchGame
git commit -m "chore: layout and accessibility pass across watch sizes"
```

## Chunk 9: Store readiness, widget and release checks

### Task 21: App icon, container scheme and README

**Files:**
- Create: `Tools/generate_icon.py`
- Create: `WatchGame/Assets.xcassets/AppIcon.appiconset/AppIcon.png` (generated)
- Modify: `WatchGame/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `WatchGame.xcodeproj/xcshareddata/xcschemes/WatchGameContainer.xcscheme`
- Create: `README.md`

- [ ] **Step 1: Generate a placeholder icon**

`Tools/generate_icon.py` writes an SVG of four Okabe-Ito shapes on a dark background and rasterises it with Quick Look:

```python
#!/usr/bin/env python3
"""Generates a 1024x1024 placeholder app icon. Replace with an Icon Composer icon before release."""
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "WatchGame" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"

SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <rect width="1024" height="1024" fill="#101418"/>
  <circle cx="330" cy="330" r="150" fill="#D55E00"/>
  <rect x="544" y="180" width="300" height="300" rx="40" fill="#F0E442"/>
  <polygon points="330,544 480,844 180,844" fill="#009E73"/>
  <polygon points="694,544 738,660 860,660 762,732 800,850 694,780 588,850 626,732 528,660 650,660" fill="#0072B2"/>
</svg>"""

with tempfile.TemporaryDirectory() as tmp:
    svg = pathlib.Path(tmp) / "icon.svg"
    svg.write_text(SVG)
    subprocess.run(["qlmanage", "-t", "-s", "1024", "-o", tmp, str(svg)], check=True, capture_output=True)
    png = pathlib.Path(tmp) / "icon.svg.png"
    OUT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["sips", "-s", "format", "png", "--resampleHeightWidth", "1024", "1024", str(png), "--out", str(OUT)], check=True, capture_output=True)
    print(f"wrote {OUT.relative_to(ROOT)}")
```

Run: `python3 Tools/generate_icon.py`
Expected: `wrote WatchGame/Assets.xcassets/AppIcon.appiconset/AppIcon.png`. Verify with `sips -g pixelWidth -g pixelHeight -g hasAlpha <file>` that it is 1024 by 1024. If `hasAlpha` is yes, flatten it: `sips -s format jpeg` then back to png is not needed; instead re-run with `--setProperty hasAlpha no` is unsupported, so use `sips -m /System/Library/ColorSync/Profiles/sRGB\ Profile.icc` and accept alpha; App Store Connect rejects alpha only for iOS icons, and the watch icon is masked by the system.

Update `WatchGame/Assets.xcassets/AppIcon.appiconset/Contents.json` to reference the file:

```json
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "watchos",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 2: Add the container scheme used for archiving**

`WatchGame.xcodeproj/xcshareddata/xcschemes/WatchGameContainer.xcscheme`: copy `WatchGame.xcscheme`, then replace every `AA000000000000000000A100` with `AA000000000000000000A200`, every `WatchGame.app` with `WatchGameContainer.app`, every `BlueprintName = "WatchGame"` with `BlueprintName = "WatchGameContainer"`, and delete the whole `<Testables>...</Testables>` block. Archiving this scheme (Product, Archive in Xcode, or `xcodebuild -scheme WatchGameContainer archive`) produces the App Store package that contains the watch app.

- [ ] **Step 3: Write the README**

`README.md`:

```markdown
# Swipe Sort

A standalone Apple Watch sorting game. Flick each item toward the edge that matches its category; the rule changes every round.

## Requirements

- macOS 26.6 or later on Apple silicon, Xcode 27.0 or later, the watchOS 27 simulator runtime.
- If `xcode-select -p` prints the Command Line Tools path, either run `sudo xcode-select -s /Applications/Xcode.app` once or rely on the scripts, which set `DEVELOPER_DIR` themselves.

## Layout

- `Packages/SwipeSortEngine`: all game rules as pure Swift, tested on macOS.
- `WatchGame`: the watchOS app (SwiftUI, SwiftData, WidgetKit).
- `WatchGameContainer`: the empty iOS container Apple requires for watch-only apps.
- `docs/superpowers`: design spec and implementation plan.

## Commands

- `Scripts/engine-test.sh`: engine unit tests.
- `Scripts/build.sh`: build the watch app for the simulator.
- `Scripts/test.sh`: watch app unit tests on a simulator (`WATCH_SIM` overrides the device name).
- `Scripts/screenshots.sh`: home-screen screenshots on every watch size.
- `python3 Tools/generate_sounds.py`, `python3 Tools/generate_icon.py`: regenerate placeholder assets.

## Release

Archive the `WatchGameContainer` scheme, set `DEVELOPMENT_TEAM` in the project (or sign in to Xcode), and upload through Organizer. Bundle identifiers are `com.pynto.swipesort` (container) and `com.pynto.swipesort.watchkitapp` (watch app).
```

- [ ] **Step 4: Build**

Run: `Scripts/build.sh`
Expected: `BUILD OK`, no asset catalog warnings about the icon.

- [ ] **Step 5: Commit**

```bash
git add Tools WatchGame WatchGame.xcodeproj README.md
git commit -m "chore: placeholder icon, container archive scheme and README"
```

### Task 22: Smart Stack widget, App Group summary and App Intent

**Files:**
- Modify: `WatchGame.xcodeproj/project.pbxproj` (new extension target)
- Create: `WatchGameWidget/Info.plist`
- Create: `WatchGameWidget/WatchGameWidgetExtension.entitlements`
- Create: `WatchGame/WatchGame.entitlements`
- Create: `WatchGame/Widget/WidgetSummary.swift` (shared file, also compiled into the extension)
- Create: `WatchGameWidget/WatchGameWidget.swift`
- Create: `WatchGame/Game/StartDailyChallengeIntent.swift`
- Modify: `WatchGame/AppEnvironment.swift`
- Modify: `WatchGame/Views/Home/HomeView.swift`
- Create: `WatchGameTests/WidgetSummaryTests.swift`

- [ ] **Step 1: Write the failing test**

`WatchGameTests/WidgetSummaryTests.swift`:

```swift
import Foundation
import Testing
@testable import WatchGame

@Suite struct WidgetSummaryTests {
    let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func day(_ day: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 10))!
    }

    @Test func displayStateForToday() {
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: 8)
        let state = summary.displayState(on: day(24), calendar: utc)
        #expect(state == WidgetSummary.DisplayState(playedToday: true, streak: 4))
    }

    @Test func displayStateTheMorningAfterAPlayedDay() {
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: nil)
        #expect(summary.displayState(on: day(25), calendar: utc) == WidgetSummary.DisplayState(playedToday: false, streak: 4))
    }

    @Test func displayStateAfterAMissedDayOrStaleFile() {
        let unplayed = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: false, dailyStreak: 4, usualPlayHour: nil)
        #expect(unplayed.displayState(on: day(25), calendar: utc) == WidgetSummary.DisplayState(playedToday: false, streak: 0))
        let stale = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: true, dailyStreak: 4, usualPlayHour: nil)
        #expect(stale.displayState(on: day(26), calendar: utc) == WidgetSummary.DisplayState(playedToday: false, streak: 0))
    }

    @Test func roundTripsThroughJSON() throws {
        let summary = WidgetSummary(dailyKey: "2026-09-24", dailyPlayedToday: false, dailyStreak: 1, usualPlayHour: 21)
        let data = try JSONEncoder().encode(summary)
        #expect(try JSONDecoder().decode(WidgetSummary.self, from: data) == summary)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `Scripts/test.sh`
Expected: compile error for `WidgetSummary`.

- [ ] **Step 3: Implement the shared summary**

`WatchGame/Widget/WidgetSummary.swift` (this file is added to both the app and the extension targets in Step 5):

```swift
import Foundation

/// The small file the app writes for the widget. Both targets compile this file.
struct WidgetSummary: Codable, Equatable, Sendable {
    static let appGroup = "group.com.pynto.swipesort"
    static let fileName = "widget-summary.json"

    /// Local calendar day the summary describes, "yyyy-MM-dd".
    var dailyKey: String
    var dailyPlayedToday: Bool
    var dailyStreak: Int
    var usualPlayHour: Int?

    struct DisplayState: Equatable, Sendable {
        var playedToday: Bool
        var streak: Int
    }

    /// Derives what to show on `date` without trusting the flags verbatim (spec 8.1).
    func displayState(on date: Date, calendar: Calendar = .current) -> DisplayState {
        let today = Self.dayKey(for: date, calendar: calendar)
        if dailyKey == today {
            return DisplayState(playedToday: dailyPlayedToday, streak: dailyStreak)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: date),
           dailyKey == Self.dayKey(for: yesterday, calendar: calendar), dailyPlayedToday {
            return DisplayState(playedToday: false, streak: dailyStreak)
        }
        return DisplayState(playedToday: false, streak: 0)
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appending(path: fileName)
    }

    static func load() -> WidgetSummary? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSummary.self, from: data)
    }

    /// Returns false when the App Group container is unavailable.
    @discardableResult
    func save() -> Bool {
        guard let url = Self.fileURL, let data = try? JSONEncoder().encode(self) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
```

`WidgetSummary.dayKey` duplicates `DailySeed.dayKey` on purpose so the extension does not need the engine package.

- [ ] **Step 4: Write the widget, its Info.plist and entitlements**

`WatchGameWidget/WatchGameWidget.swift`:

```swift
import SwiftUI
import WidgetKit

struct DailyEntry: TimelineEntry {
    let date: Date
    let state: WidgetSummary.DisplayState
}

struct DailyProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyEntry {
        DailyEntry(date: .now, state: .init(playedToday: false, streak: 3))
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyEntry) -> Void) {
        completion(entry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyEntry>) -> Void) {
        let now = Date.now
        var entries = [entry(for: now)]
        if let midnight = Calendar.current.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            entries.append(entry(for: midnight))
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    func relevances() async -> WidgetRelevances<Void> {
        guard let hour = WidgetSummary.load()?.usualPlayHour,
              let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now)
        else { return WidgetRelevances() }
        let interval = DateInterval(start: start.addingTimeInterval(-30 * 60), duration: 60 * 60)
        return WidgetRelevances([WidgetRelevanceEntry(context: .date(interval: interval, kind: .scheduled))])
    }

    private func entry(for date: Date) -> DailyEntry {
        let summary = WidgetSummary.load() ?? WidgetSummary(dailyKey: "", dailyPlayedToday: false, dailyStreak: 0, usualPlayHour: nil)
        return DailyEntry(date: date, state: summary.displayState(on: date))
    }
}

struct DailyWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Image(systemName: entry.state.playedToday ? "checkmark" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14, weight: .bold))
                    Text("\(entry.state.streak)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
        default:
            HStack(spacing: 8) {
                Image(systemName: entry.state.playedToday ? "checkmark.circle.fill" : "square.grid.2x2.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.state.playedToday ? "Daily done" : "Play today's challenge")
                        .font(.headline)
                        .lineLimit(1)
                    Text(entry.state.streak == 1 ? "1 day streak" : "\(entry.state.streak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

@main
struct WatchGameWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "com.pynto.swipesort.daily", provider: DailyProvider()) { entry in
            DailyWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "swipesort://daily"))
        }
        .configurationDisplayName("Daily challenge")
        .description("Today's status and your streak.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}
```

`WatchGameWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>NSExtension</key>
	<dict>
		<key>NSExtensionPointIdentifier</key>
		<string>com.apple.widgetkit-extension</string>
	</dict>
</dict>
</plist>
```

`WatchGameWidget/WatchGameWidgetExtension.entitlements` and `WatchGame/WatchGame.entitlements` (identical content):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.pynto.swipesort</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 5: Add the extension target to the project**

Edit `WatchGame.xcodeproj/project.pbxproj`:

1. In `PBXBuildFile`, add:

```
		AA000000000000000000A10C /* WatchGameWidgetExtension.appex in Embed Foundation Extensions */ = {isa = PBXBuildFile; fileRef = AA000000000000000000A401 /* WatchGameWidgetExtension.appex */; settings = {ATTRIBUTES = (RemoveHeadersOnCopy, ); }; };
		AA000000000000000000A40B /* WidgetSummary.swift in Sources */ = {isa = PBXBuildFile; fileRef = AA000000000000000000A40C /* WidgetSummary.swift */; };
```

2. In `PBXContainerItemProxy`, add:

```
		AA000000000000000000A10E /* PBXContainerItemProxy */ = {
			isa = PBXContainerItemProxy;
			containerPortal = AA00000000000000000000A1 /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = AA000000000000000000A400;
			remoteInfo = WatchGameWidgetExtension;
		};
```

3. In `PBXCopyFilesBuildPhase`, add:

```
		AA000000000000000000A10B /* Embed Foundation Extensions */ = {
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				AA000000000000000000A10C /* WatchGameWidgetExtension.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		};
```

4. In `PBXFileReference`, add:

```
		AA000000000000000000A401 /* WatchGameWidgetExtension.appex */ = {isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = WatchGameWidgetExtension.appex; sourceTree = BUILT_PRODUCTS_DIR; };
		AA000000000000000000A40C /* WidgetSummary.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = WidgetSummary.swift; path = WatchGame/Widget/WidgetSummary.swift; sourceTree = SOURCE_ROOT; };
```

5. In `PBXFileSystemSynchronizedRootGroup`, add:

```
		AA000000000000000000A402 /* WatchGameWidget */ = {
			isa = PBXFileSystemSynchronizedRootGroup;
			path = WatchGameWidget;
			sourceTree = "<group>";
		};
```

6. Add a `PBXFrameworksBuildPhase` `AA000000000000000000A404`, a `PBXResourcesBuildPhase` `AA000000000000000000A405` (both with empty `files`), and a `PBXSourcesBuildPhase` `AA000000000000000000A403` whose `files` contains `AA000000000000000000A40B /* WidgetSummary.swift in Sources */`.

7. Add the target to `PBXNativeTarget`:

```
		AA000000000000000000A400 /* WatchGameWidgetExtension */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = AA000000000000000000A406 /* Build configuration list for PBXNativeTarget "WatchGameWidgetExtension" */;
			buildPhases = (
				AA000000000000000000A403 /* Sources */,
				AA000000000000000000A404 /* Frameworks */,
				AA000000000000000000A405 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			fileSystemSynchronizedGroups = (
				AA000000000000000000A402 /* WatchGameWidget */,
			);
			name = WatchGameWidgetExtension;
			packageProductDependencies = (
			);
			productName = WatchGameWidgetExtension;
			productReference = AA000000000000000000A401 /* WatchGameWidgetExtension.appex */;
			productType = "com.apple.product-type.app-extension";
		};
```

8. In the `WatchGame` target: add `AA000000000000000000A10B /* Embed Foundation Extensions */` after Resources in `buildPhases`, and add `AA000000000000000000A10D /* PBXTargetDependency */` to `dependencies`. In `PBXTargetDependency` add:

```
		AA000000000000000000A10D /* PBXTargetDependency */ = {
			isa = PBXTargetDependency;
			target = AA000000000000000000A400 /* WatchGameWidgetExtension */;
			targetProxy = AA000000000000000000A10E /* PBXContainerItemProxy */;
		};
```

9. Add `AA000000000000000000A402 /* WatchGameWidget */` to the main group's children, `AA000000000000000000A401` to the Products group, `AA000000000000000000A400` to the project's `targets`, and `AA000000000000000000A400 = { CreatedOnToolsVersion = 27.0; };` to `TargetAttributes`.

10. Add build configurations `AA000000000000000000A407` (Debug) and `AA000000000000000000A408` (Release) with these settings, and the configuration list `AA000000000000000000A406` referencing them:

```
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = WatchGameWidget/WatchGameWidgetExtension.entitlements;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = WatchGameWidget/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = "Swipe Sort";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
					"@executable_path/../../Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort.watchkitapp.widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				TARGETED_DEVICE_FAMILY = 4;
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
```

11. In both `WatchGame` target configurations (`A107`, `A108`) add `CODE_SIGN_ENTITLEMENTS = WatchGame/WatchGame.entitlements;`.

Run `plutil -lint WatchGame.xcodeproj/project.pbxproj` after editing; it must print `OK`.

- [ ] **Step 6: Write the summary from the app and add the intent**

`WatchGame/Game/StartDailyChallengeIntent.swift`:

```swift
import AppIntents

struct StartDailyChallengeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Daily Challenge"
    static let description = IntentDescription("Opens Swipe Sort and starts today's challenge.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        LaunchRequests.shared.requestDaily()
        return .result()
    }
}

struct WatchGameShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartDailyChallengeIntent(),
            phrases: ["Start today's \(.applicationName) challenge", "Play the \(.applicationName) daily"],
            shortTitle: "Daily challenge",
            systemImageName: "calendar"
        )
    }
}
```

In `WatchGame/AppEnvironment.swift` add:

```swift
import WidgetKit

extension AppEnvironment {
    /// Writes the widget summary and asks WidgetKit to refresh. Safe to call often.
    func refreshWidgetSummary(now: Date = .now) {
        let key = DailySeed.dayKey(for: now)
        let summary = WidgetSummary(
            dailyKey: key,
            dailyPlayedToday: history.hasCompletedDaily(dayKey: key),
            dailyStreak: history.dailyStreak(today: now),
            usualPlayHour: usualPlayHour()
        )
        if summary.save() {
            WidgetCenter.shared.reloadAllTimelines()
        } else {
            Logger(subsystem: "com.pynto.swipesort", category: "widget").error("App Group container unavailable; widget summary not written")
        }
    }

    /// Most common start hour over the last 30 completed runs, when there are at least 3.
    func usualPlayHour(calendar: Calendar = .current) -> Int? {
        let runs = history.completedRuns(limit: 30)
        guard runs.count >= 3 else { return nil }
        let counts = Dictionary(grouping: runs) { calendar.component(.hour, from: $0.startedAt) }
            .mapValues(\.count)
        return counts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key
    }
}
```

Add `import OSLog` to `AppEnvironment.swift`. Call `environment.refreshWidgetSummary()` in three places: at the end of `AppEnvironment.live()` (before `return`), in `HomeView.dismissRun()` after clearing the session, and in `SettingsView` after `environment.history.reset()`.

- [ ] **Step 7: Build and test**

Run: `Scripts/build.sh` then `Scripts/test.sh`
Expected: `BUILD OK`, `TESTS OK`. If the build complains that the extension needs an `@main` and finds two, ensure `WidgetSummary.swift` is the only app file compiled into the extension (its `PBXBuildFile` is the only entry in the extension's Sources phase besides the synchronized folder).

- [ ] **Step 8: Verify the widget on the simulator**

Install and launch the app on a booted simulator, play one daily to completion, then add the widget to the Smart Stack in the simulator (long press the watch face, Edit, add "Swipe Sort"). Expected: it shows "Daily done" and the streak. Tap it: the app opens on Home (no new run starts because the daily is already done for today only if a run is in progress; otherwise it starts the daily, which is the specified behaviour).

- [ ] **Step 9: Commit**

```bash
git add WatchGame WatchGameWidget WatchGameTests WatchGame.xcodeproj
git commit -m "feat(widget): Smart Stack daily widget, App Group summary, relevance and daily intent"
```

### Task 23: UI smoke test, hardware checklist and TestFlight

**Files:**
- Modify: `WatchGame.xcodeproj/project.pbxproj` (UI test target)
- Modify: `WatchGame.xcodeproj/xcshareddata/xcschemes/WatchGame.xcscheme`
- Create: `WatchGameUITests/LaunchAndPlayTests.swift`
- Create: `docs/release-checklist.md`

- [ ] **Step 1: Add the UI test target**

In `project.pbxproj` add a target `WatchGameUITests` with id `AA000000000000000000A500`, product `AA000000000000000000A501` (`WatchGameUITests.xctest`, `explicitFileType = wrapper.cfbundle`), synchronized root group `AA000000000000000000A502` (`path = WatchGameUITests`), Sources `A503`, Frameworks `A504`, Resources `A505`, configuration list `A506` with Debug `A507` and Release `A508`, a dependency `A509` on the `WatchGame` target through proxy `A50A`, `productType = "com.apple.product-type.bundle.ui-testing"`, and `TargetAttributes` entry `AA000000000000000000A500 = { CreatedOnToolsVersion = 27.0; TestTargetID = AA000000000000000000A100; };`. Build settings for `A507`/`A508`:

```
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.pynto.swipesort.watchkitapp.uitests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SDKROOT = watchos;
				SWIFT_EMIT_LOC_STRINGS = NO;
				TARGETED_DEVICE_FAMILY = 4;
				TEST_TARGET_NAME = WatchGame;
				WATCHOS_DEPLOYMENT_TARGET = 26.0;
```

Add the group to the main group, the product to Products, and the target to `targets`. In `WatchGame.xcscheme`, add a second `TestableReference` for `AA000000000000000000A500` / `WatchGameUITests.xctest` / `WatchGameUITests`. Run `plutil -lint` on the pbxproj.

- [ ] **Step 2: Write the smoke test**

`WatchGameUITests/LaunchAndPlayTests.swift` (XCTest is required for UI tests):

```swift
import XCTest

final class LaunchAndPlayTests: XCTestCase {
    @MainActor
    func testLaunchPlayShowsFirstItem() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        app.buttons["Play"].tap()
        // Round intro auto-starts after 2.5 seconds; the item is the only element with a category label.
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 6), "play screen did not appear")
        pause.tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 2))
    }
}
```

Run: `Scripts/test.sh -only-testing:WatchGameUITests`
Expected: `TESTS OK`.

- [ ] **Step 3: Write the release checklist**

`docs/release-checklist.md`:

```markdown
# Release checklist

## Simulator layout pass
- [ ] `Scripts/screenshots.sh` runs clean on 41, 42, 44, 45, 46 and 49 mm.
- [ ] Play screen on 41 mm with Tap to sort on: no label overlaps the item; every label is at least 44 pt tall.

## Hardware pass (one watch per size class if possible)
- [ ] Flicks starting near the left edge do not trigger back navigation; flicks near top and bottom do not open system surfaces.
- [ ] Ambient audio: sounds mix with a playing podcast; Silent Mode mutes them; haptics still fire.
- [ ] Wrist down mid-round pauses; raising the wrist shows Paused; Resume continues with the ring where it was.
- [ ] Double Tap pauses and resumes on Series 9 or later.
- [ ] Reduce Motion: no fly-off, no confetti, crossfades only.
- [ ] VoiceOver: every screen navigable; the item reads its category; custom actions sort it; Tap to sort is forced on.
- [ ] Tap to sort mode: all four labels tappable, swipes still work.
- [ ] Full 8-round run reaches Results with the breakdown; History shows the run; daily streak increments the next day.
- [ ] Widget shows today's status; tapping it opens the daily when no run is in progress.

## App Store Connect
- [ ] Set `DEVELOPMENT_TEAM` in the project or sign in to Xcode; bundle ids registered with the App Group capability.
- [ ] Replace the placeholder icon with an Icon Composer icon; replace placeholder sounds if designed ones exist.
- [ ] Archive the `WatchGameContainer` scheme and upload with Organizer.
- [ ] Privacy: no data collected; privacy manifest present in the watch app.
- [ ] Age rating 4+; accessibility nutrition label: VoiceOver, Reduce Motion, Differentiate Without Colour Alone, Sufficient Contrast.
- [ ] Export compliance: no encryption beyond the OS; answer "No" when asked.
- [ ] Screenshots for every required watch size; category Games, subcategory Puzzle; price tier set.
- [ ] TestFlight build installed on a real watch and the hardware pass above completed.
```

- [ ] **Step 4: Commit**

```bash
git add WatchGame.xcodeproj WatchGameUITests docs/release-checklist.md
git commit -m "test(ui): launch-and-play smoke test; docs: release checklist"
```

## Execution notes

- Tasks 1 to 9 need only macOS and `swift test`; they can be done before the watchOS simulator runtime is available.
- Tasks 10 onwards need `Scripts/build.sh` (no simulator device required, only the SDK) and `Scripts/test.sh` (needs a booted watchOS 27 simulator).
- Each task is independent enough for a fresh subagent given this plan, the spec, and the previous commits.
