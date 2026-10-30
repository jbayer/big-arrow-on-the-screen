@testable import BigArrowCore
@testable import BigArrowOverlay
import CoreGraphics
import Foundation
import ImageIO
import Testing

/// The sign's X and the click region, computed offscreen; nothing is drawn on the screen.
@Suite("Sign and click region")
@MainActor
struct SignAndClickTests {
    let display = Display(index: 0, id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                          visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)

    func appearance(_ mark: CloseMark) throws -> SignAppearance {
        var appearance = SignAppearance(color: try ArrowColor.parse("red"), size: .medium, corners: .round)
        appearance.closeMark = mark
        return appearance
    }

    @Test("The X widens the sign by at least its own diameter, so it never covers the text")
    func crossMakesRoom() throws {
        let text = try SignText.parse("Franz, click Allow")
        let plain = SignRenderer.render(text: text, appearance: try appearance(.none), display: display)
        let crossed = SignRenderer.render(text: text, appearance: try appearance(.cross), display: display)
        #expect(crossed.size.height == plain.size.height)
        #expect(crossed.size.width - plain.size.width >= SignRenderer.crossMinimum)
    }

    @Test("The default drop shadow fades out completely inside the PNG, never cut at its edge")
    func shadowIsNotCut() throws {
        let appearance = try appearance(.none)
        let sign = SignRenderer.render(text: try SignText.parse("Franz, click Allow"), appearance: appearance, display: display)
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 600, y: 400)), display: display, signSize: sign.size,
            style: .box, size: .medium, forced: .bottomRight
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bigarrow-shadow-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }
        try PNGExporter.write(layout, sign: sign, appearance: appearance, to: url)
        let image = try #require(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        let (width, height) = (image.width, image.height)
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let alpha = { (x: Int, y: Int) in Int(pixels[(y * width + x) * 4 + 3]) }
        let border = (0..<width).flatMap { [alpha($0, 0), alpha($0, height - 1)] }
            + (0..<height).flatMap { [alpha(0, $0), alpha(width - 1, $0)] }
        #expect(border.allSatisfy { $0 == 0 }, "the shadow reaches the PNG's edge (max alpha \(border.max() ?? 0))")
    }

    @Test("A click counts on the sign and the shaft, never near the tip or on the target")
    func region() throws {
        let sign = SignRenderer.render(text: try SignText.parse("Franz, click Allow"), appearance: try appearance(.none), display: display)
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 300, y: 250)), display: display, signSize: sign.size,
            style: .arrow, size: .medium, forced: .bottomRight
        ))
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: display.frame.height)
        let region = ClickRegion(layout: layout, flip: flip)
        let signCenter = CGPoint(x: layout.signRect.midX, y: layout.signRect.midY).applying(flip)
        #expect(region.contains(signCenter))
        #expect(!region.contains(CGPoint(x: 300, y: 250).applying(flip)))
        #expect(!region.contains(layout.arrow.tip.applying(flip)))
        #expect(!region.contains(CGPoint(x: 1400, y: 60)))
        let shaftMiddle = layout.arrow.shaftPath.boundingBoxOfPath.center.applying(flip)
        let onShaft = (0..<40).contains { step in
            region.contains(CGPoint(x: shaftMiddle.x + CGFloat(step - 20) * 3, y: shaftMiddle.y))
        }
        #expect(onShaft)
    }
}
