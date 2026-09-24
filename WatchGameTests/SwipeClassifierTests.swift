import CoreGraphics
import Testing
import SwipeSortEngine
@testable import WatchGame

@Suite struct SwipeClassifierTests {
    let classifier = SwipeClassifier()
    let bounds = CGSize(width: 198, height: 242)
    let centre = CGPoint(x: 99, y: 121)

    func classify(_ dx: CGFloat, _ dy: CGFloat, predicted: CGSize? = nil, start: CGPoint? = nil) -> SwipeEdge? {
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
