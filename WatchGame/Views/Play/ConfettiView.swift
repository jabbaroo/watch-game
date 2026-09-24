import SwiftUI

/// A one-second burst of at most 40 particles drawn with Canvas. Skipped under Reduce Motion.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var particles: [Particle] = (0..<40).map { _ in Particle() }
    @State private var start = Date()
    @State private var finished = false

    struct Particle {
        let angle = Double.random(in: 0 ..< 2 * .pi)
        let speed = Double.random(in: 60 ... 140)
        let size = Double.random(in: 3 ... 6)
        let hue = Double.random(in: 0 ... 1)
    }

    var body: some View {
        if !reduceMotion {
            TimelineView(.animation(paused: finished)) { context in
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
            .task {
                try? await Task.sleep(for: .seconds(1))
                finished = true
            }
        }
    }
}
