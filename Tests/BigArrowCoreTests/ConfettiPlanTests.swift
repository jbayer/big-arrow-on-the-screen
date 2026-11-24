import BigArrowCore
import CoreGraphics
import Foundation
import Testing

@Suite("Confetti plan")
struct ConfettiPlanTests {
    static let sizes = [
        CGSize(width: 1512, height: 982), CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440)
    ]

    /// Height of a piece above the source after `t` seconds, at its source's speed and angle.
    func height(_ source: ConfettiSource, after t: Double) -> Double {
        Double(source.speed) * sin(Double(source.angle)) * t - Double(source.gravity) / 2 * t * t
    }

    @Test("Confetti comes from every side: top, both bottom corners, both side edges, the bottom", arguments: sizes)
    func everySide(size: CGSize) throws {
        let sources = try ConfettiPlan(display: size).sources
        let at = sources.map(\.position)
        #expect(at.contains { $0.y > size.height }, "nothing from the top")
        #expect(at.contains { $0.x == 0 && $0.y == 0 }, "nothing from the bottom-left corner")
        #expect(at.contains { $0.x == size.width && $0.y == 0 }, "nothing from the bottom-right corner")
        #expect(at.contains { $0.x == 0 && $0.y > 0 && $0.y < size.height }, "nothing from the left edge")
        #expect(at.contains { $0.x == size.width && $0.y > 0 && $0.y < size.height }, "nothing from the right edge")
        #expect(at.contains { $0.y <= 0 && $0.x == size.width / 2 }, "nothing from the bottom middle")
        // Left sources aim right, right sources aim left: every cannon shoots inwards.
        for source in sources where source.position.x == 0 { #expect(cos(source.angle) > 0) }
        for source in sources where source.position.x == size.width { #expect(cos(source.angle) < 0) }
    }

    @Test("Bottom cannons reach well up the screen, and every piece lands before the time is up", arguments: sizes)
    func reachAndTiming(size: CGSize) throws {
        let plan = try ConfettiPlan(display: size)
        for source in plan.sources where source.angle > 0 && source.position.y <= 0 {
            let up = Double(source.speed) * sin(Double(source.angle))
            let apex = up * up / (2 * Double(source.gravity))
            #expect(apex >= Double(size.height) * 0.55, "a bottom cannon only reaches \(apex) of \(size.height) pt")
        }
        for source in plan.sources {
            #expect(source.burst + source.lifetime <= plan.duration + 0.001, "\(source) outlives the show")
            #expect(source.burst >= 0.2)
            // At its lifetime, even its slowest-to-land piece is below the bottom edge.
            #expect(Double(source.position.y) + height(source, after: source.lifetime) < 0)
        }
    }

    @Test("The rain falls past the bottom edge within its lifetime and rains for more than a second")
    func rain() throws {
        let plan = try ConfettiPlan(display: Self.sizes[0])
        let rain = try #require(plan.sources.first { $0.angle < 0 })
        #expect(rain.width >= Self.sizes[0].width)
        #expect(rain.burst > 1, "the rain only lasts \(rain.burst) s")
    }

    @Test("Wider displays get more confetti, so the density is the same")
    func scalesWithWidth() throws {
        let narrow = try ConfettiPlan(display: CGSize(width: 1000, height: 800))
        let wide = try ConfettiPlan(display: CGSize(width: 2000, height: 800))
        #expect(zip(narrow.sources, wide.sources).allSatisfy { $1.piecesPerSecond == $0.piecesPerSecond * 2 })
        #expect(narrow.totalPieces > 500, "too little confetti: \(narrow.totalPieces) pieces")
    }

    @Test("Every arrow colour but black and white, each in every shape")
    func colours() {
        #expect(ConfettiPlan.colors.count == ArrowColor.presets.count - 2)
        #expect(!ConfettiPlan.colors.contains(.black))
        #expect(ConfettiPiece.allCases.count == 3)
    }

    @Test("A duration of 0, below 0, infinite or above 30 s is bad input", arguments: [0, -1, 31, Double.infinity])
    func badDuration(seconds: Double) {
        #expect(throws: BigArrowError.self) { try ConfettiPlan(display: Self.sizes[0], duration: seconds) }
    }

    @Test("A short show still fires every source")
    func shortShow() throws {
        let plan = try ConfettiPlan(display: Self.sizes[0], duration: 1)
        #expect(plan.sources.allSatisfy { $0.burst >= 0.2 && $0.burst <= 1 })
    }
}
