@testable import BigArrowCore
@testable import BigArrowOverlay
import QuartzCore
import Testing

/// The box or ring around the target, computed offscreen; nothing is drawn.
@Suite("Target mark")
@MainActor
struct MarkTests {
    let display = Display(index: 0, id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                          visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)

    func layers(_ style: ArrowStyle) throws -> (OverlayLayout, OverlayLayers) {
        let appearance = SignAppearance(color: try ArrowColor.parse("blue"), size: .medium, corners: .round)
        let sign = SignRenderer.render(text: try SignText.parse("Franz, click Save"), appearance: appearance, display: display)
        let target = CGRect(x: 1300, y: 120, width: 80, height: 28)
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .rect(target), display: display, signSize: sign.size, style: style, size: .medium, forced: nil
        ))
        return (layout, OverlayLayers(layout: layout, sign: sign, appearance: appearance))
    }

    @Test("Boxes and rings are outlines only, so the target stays visible", arguments: [ArrowStyle.box, .ring])
    func markIsOutlineOnly(style: ArrowStyle) throws {
        let (_, layers) = try layers(style)
        let shapes = (layers.markGroup.sublayers ?? []).compactMap { $0 as? CAShapeLayer }
        #expect(!shapes.isEmpty)
        #expect(shapes.allSatisfy { $0.fillColor == nil })
    }

    /// Found by @jarombouts in PR #37: the mark's layer covers the whole display, so an unpinned
    /// pulse scaled it around the display's centre and a box away from the centre swam.
    @Test("At full pulse the box's centre stays on the target", arguments: [ArrowStyle.box, .ring])
    func markPulsesInPlace(style: ArrowStyle) throws {
        let (layout, layers) = try layers(style)
        let area = try #require(layout.mark.area)
        let centre = CGPoint(x: area.midX, y: area.midY).applying(layers.flip)
        let before = layers.markGroup.convert(centre, to: layers.root)
        layers.markGroup.transform = CATransform3DMakeScale(Animator.pulseScale, Animator.pulseScale, 1)
        let after = layers.markGroup.convert(centre, to: layers.root)
        #expect(hypot(before.x - centre.x, before.y - centre.y) < 0.5)
        #expect(hypot(after.x - centre.x, after.y - centre.y) < 0.5)
    }
}
