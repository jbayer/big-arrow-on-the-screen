import AppKit
import BigArrowCore
import QuartzCore

/// Confetti over whole displays, in the same click-through, non-activating panels as the arrow.
/// Core Animation's particle emitters do the work in the render server; the show ends by itself
/// after its duration, so it can never outlive the process that started it.
@MainActor
public final class ConfettiShow {
    private var panels: [OverlayPanel] = []
    static let fadeOut: CFTimeInterval = 0.3

    public init() {}

    /// The window-server numbers of the confetti panels, for tests.
    public var windowNumbers: [Int] { panels.map(\.windowNumber) }

    /// Starts confetti on every display and calls `completion` once the time is up.
    public func start(on displays: [Display], duration: TimeInterval, completion: @escaping @MainActor () -> Void) throws {
        let plans = try displays.map { try ConfettiPlan(display: $0.frame.size, duration: duration) }
        for (display, plan) in zip(displays, plans) {
            guard let screen = ScreenReader.screen(for: display) else {
                throw BigArrowError.unresolvable("display \(display.index + 1) is no longer connected")
            }
            let panel = OverlayPanel(screen: screen) { _ in }
            let images = ConfettiEmitter.images(scale: display.scale)
            for source in plan.sources {
                let emitter = ConfettiEmitter.make(source, size: plan.size, images: images, scale: display.scale)
                panel.contentView?.layer?.addSublayer(emitter)
                after(source.burst) { emitter.birthRate = 0 }
            }
            panel.orderFrontRegardless()
            panels.append(panel)
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

    /// Ends the show at once.
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

/// One particle emitter per source, one cell per colour and shape.
@MainActor
enum ConfettiEmitter {
    static func make(_ source: ConfettiSource, size: CGSize, images: [(ConfettiPiece, CGImage)], scale: CGFloat) -> CAEmitterLayer {
        let layer = CAEmitterLayer()
        layer.frame = CGRect(origin: .zero, size: size)
        // The content view is not flipped: y grows upwards, as the plan's positions do.
        layer.emitterPosition = source.position
        layer.emitterSize = CGSize(width: max(source.width, 1), height: 1)
        layer.emitterShape = source.width > 0 ? .line : .point
        layer.renderMode = .unordered
        // Without this the emitter back-fills its age since the layer's creation in one clump.
        layer.beginTime = CACurrentMediaTime()
        let rate = Float(source.piecesPerSecond) / Float(ConfettiPlan.colors.count * images.count)
        layer.emitterCells = ConfettiPlan.colors.flatMap { color in
            images.map { piece, image in
                let cell = cell(image, color: color, source: source, scale: scale)
                cell.birthRate = rate
                // Strips flutter fast, squares turn, dots barely spin.
                cell.spinRange = piece == .strip ? 14 : piece == .square ? 8 : 2
                return cell
            }
        }
        return layer
    }

    static func cell(_ image: CGImage, color: ArrowColor, source: ConfettiSource, scale: CGFloat) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = image
        cell.contentsScale = scale
        cell.color = color.cgColor
        cell.lifetime = Float(source.lifetime)
        cell.velocity = source.speed
        cell.velocityRange = source.speed * ConfettiSource.speedRange
        cell.emissionLongitude = source.angle
        cell.emissionRange = source.spread
        cell.yAcceleration = -source.gravity
        cell.spin = 2
        cell.scaleRange = 0.35
        return cell
    }

    /// One white image per shape; the cell's colour tints it.
    static func images(scale: CGFloat) -> [(ConfettiPiece, CGImage)] {
        ConfettiPiece.allCases.map { piece in
            let rect = CGRect(origin: .zero, size: piece.size)
            let image = Canvas(size: piece.size, scale: scale).render { context in
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                switch piece {
                case .strip, .square: context.addPath(CGPath(roundedRect: rect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
                case .dot: context.addEllipse(in: rect)
                }
                context.fillPath()
            }
            return (piece, image)
        }
    }
}
