import AppKit
import BigArrowCore
import QuartzCore

/// Confetti over whole displays, in the same click-through, non-activating panels as the arrow.
/// Core Animation's particle emitter does the work in the render server; the show ends by itself
/// after its duration, so it can never outlive the process that started it.
@MainActor
public final class ConfettiShow {
    private var panels: [OverlayPanel] = []
    static let fadeOut: CFTimeInterval = 0.3

    public init() {}

    /// The window-server numbers of the confetti panels, for tests.
    public var windowNumbers: [Int] { panels.map(\.windowNumber) }

    /// Starts confetti on every display and calls `completion` once the last piece is gone.
    public func start(on displays: [Display], duration: TimeInterval, completion: @escaping @MainActor () -> Void) throws {
        let plans = try displays.map { try ConfettiPlan(display: $0.frame.size, duration: duration) }
        for (display, plan) in zip(displays, plans) {
            guard let screen = ScreenReader.screen(for: display) else {
                throw BigArrowError.unresolvable("display \(display.index + 1) is no longer connected")
            }
            let panel = OverlayPanel(screen: screen) { _ in }
            let emitter = ConfettiEmitter.make(plan, scale: display.scale)
            panel.contentView?.layer?.addSublayer(emitter)
            panel.orderFrontRegardless()
            panels.append(panel)
            after(plan.burst) { emitter.birthRate = 0 }
        }
        after(max(duration - Self.fadeOut, 0)) { self.fade() }
        after(duration) {
            self.close()
            completion()
        }
    }

    private func fade() {
        for layer in panels.compactMap({ $0.contentView?.layer }) {
            Animator.fade(layer, from: 1, to: 0, duration: Self.fadeOut)
        }
    }

    /// Ends the show at once, for an arrow that is dismissed while confetti still falls.
    public func close() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels = []
    }

    private func after(_ seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { MainActor.assumeIsolated { work() } }
    }
}

/// The particle emitter: a line just above the display's top edge, wider than the display so the
/// corners get confetti too, raining one cell per colour and shape.
@MainActor
enum ConfettiEmitter {
    static func make(_ plan: ConfettiPlan, scale: CGFloat) -> CAEmitterLayer {
        let layer = CAEmitterLayer()
        layer.frame = CGRect(origin: .zero, size: plan.size)
        // The content view is not flipped: y grows upwards, so the top edge is at `height`.
        layer.emitterPosition = CGPoint(x: plan.size.width / 2, y: plan.size.height + 30)
        layer.emitterSize = CGSize(width: plan.size.width * 1.1, height: 1)
        layer.emitterShape = .line
        layer.renderMode = .unordered
        // Without this the emitter back-fills its age since the layer's creation in one clump.
        layer.beginTime = CACurrentMediaTime()
        let pieces = ConfettiPiece.allCases.map { ($0, image($0, scale: scale)) }
        layer.emitterCells = ConfettiPlan.colors.flatMap { color in
            pieces.map { cell($0.1, color: color, plan: plan, scale: scale) }
        }
        return layer
    }

    static func cell(_ image: CGImage, color: ArrowColor, plan: ConfettiPlan, scale: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.contentsScale = scale
        cell.color = color.cgColor
        cell.birthRate = plan.birthRatePerCell
        cell.lifetime = Float(plan.lifetime)
        cell.velocity = ConfettiPlan.initialSpeed
        cell.velocityRange = ConfettiPlan.initialSpeed * 0.6
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = .pi / 4
        cell.yAcceleration = -ConfettiPlan.gravity
        cell.xAcceleration = 0
        cell.spin = 2
        cell.spinRange = 9
        cell.scaleRange = 0.35
        return cell
    }

    /// A white piece; the cell's colour tints it.
    static func image(_ piece: ConfettiPiece, scale: CGFloat) -> CGImage {
        let rect = CGRect(origin: .zero, size: piece.size)
        return Canvas(size: piece.size, scale: scale).render { context in
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            switch piece {
            case .strip, .square: context.addPath(CGPath(roundedRect: rect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
            case .dot: context.addEllipse(in: rect)
            }
            context.fillPath()
        }
    }
}
