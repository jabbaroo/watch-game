import CoreGraphics
import SwipeSortEngine

/// Turns a finished drag into an edge, or nil when the gesture should be ignored (spec section 4).
struct SwipeClassifier {
    var minimumTranslation: CGFloat = 24
    var minimumPredictedTranslation: CGFloat = 60
    /// Minor axis over major axis above this ratio is "within 20 percent" and ambiguous.
    var ambiguityRatio: CGFloat = 0.8
    var edgeExclusion: CGFloat = 14

    func edge(start: CGPoint, translation: CGSize, predictedTranslation: CGSize, bounds: CGSize) -> SwipeEdge? {
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
