import Testing
import SwipeSortEngine
@testable import WatchGame

@Suite struct SmokeTests {
    @Test func engineIsLinked() {
        #expect(ContentPack.shapesAndColours.items.count == 16)
    }
}
