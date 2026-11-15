import BigArrowCore
import CoreGraphics
import Testing

@Suite("Confetti plan")
struct ConfettiPlanTests {
    let builtIn = TestDisplays.builtIn.frame.size

    @Test("A piece falls past the bottom edge within its lifetime")
    func coversTheWholeHeight() throws {
        let plan = try ConfettiPlan(display: builtIn)
        let t = plan.lifetime
        let fallen = Double(ConfettiPlan.initialSpeed) * t + Double(ConfettiPlan.gravity) / 2 * t * t
        #expect(fallen > Double(builtIn.height) + 30, "a piece only falls \(fallen) pt in \(t) s")
    }

    @Test("The last pieces born land before the time is up")
    func endsInTime() throws {
        let plan = try ConfettiPlan(display: builtIn)
        #expect(plan.burst + plan.lifetime <= plan.duration + 0.001)
        #expect(plan.burst > 1, "the default show should rain for more than a second, got \(plan.burst) s")
    }

    @Test("Wider displays get more confetti, so the density is the same")
    func scalesWithWidth() throws {
        let narrow = try ConfettiPlan(display: CGSize(width: 1000, height: 800))
        let wide = try ConfettiPlan(display: CGSize(width: 2000, height: 800))
        #expect(wide.piecesPerSecond == narrow.piecesPerSecond * 2)
        #expect(narrow.totalPieces > 300, "too thin a rain: \(narrow.totalPieces) pieces")
    }

    @Test("Every arrow colour but black and white, each in every shape")
    func colours() {
        #expect(ConfettiPlan.colors.count == ArrowColor.presets.count - 2)
        #expect(!ConfettiPlan.colors.contains(.black))
        #expect(ConfettiPiece.allCases.count == 3)
    }

    @Test("A duration of 0, below 0, infinite or above 30 s is bad input", arguments: [0, -1, 31, Double.infinity])
    func badDuration(seconds: Double) {
        #expect(throws: BigArrowError.self) { try ConfettiPlan(display: builtIn, duration: seconds) }
    }

    @Test("A short show still gets a puff of confetti")
    func shortShow() throws {
        let plan = try ConfettiPlan(display: builtIn, duration: 1)
        #expect(plan.burst >= 0.4)
        #expect(plan.burst <= 1)
    }
}
