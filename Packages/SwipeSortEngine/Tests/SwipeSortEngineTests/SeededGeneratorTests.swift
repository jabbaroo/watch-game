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
