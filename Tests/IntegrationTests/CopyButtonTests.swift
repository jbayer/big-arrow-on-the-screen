@testable import BigArrowCore
@testable import BigArrowOverlay
import CoreGraphics
import Foundation
import Testing

/// Copy chips in the sign, rendered offscreen; nothing is drawn on the screen.
@Suite("Copy buttons")
@MainActor
struct CopyButtonTests {
    let display = Display(index: 0, id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                          visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 982), scale: 2)
    let appearance = SignAppearance(color: ArrowColor(red: 1, green: 0.23, blue: 0.12), size: .medium, corners: .round)

    func render(_ text: String) throws -> SignImage {
        SignRenderer.render(text: try SignText.parse(text), appearance: appearance, display: display)
    }

    @Test("Every chip lies inside the sign, in reading order, without overlapping")
    func chipsInsideSign() throws {
        let sign = try render("User {{franz}} and password {{correct horse battery staple}}")
        let bounds = CGRect(origin: .zero, size: sign.size)
        #expect(sign.copyButtons.map(\.value) == ["franz", "correct horse battery staple"])
        for button in sign.copyButtons {
            #expect(bounds.contains(button.rect), "\(button.rect) leaves the sign \(bounds)")
        }
        let (first, second) = (sign.copyButtons[0].rect, sign.copyButtons[1].rect)
        #expect(!first.intersects(second))
        #expect(first.maxY > second.maxY || first.minX < second.minX, "the second chip comes after the first")
    }

    @Test("The check replaces the icon only inside the clicked chip, so the click area is exactly the drawn chip")
    func checkStaysInChip() throws {
        let sign = try render("Franz, copy {{sudo xcodebuild -license accept}} and paste it here")
        let button = try #require(sign.copyButtons.first)
        let bounds = try Self.differingBounds(sign.text, button.copiedText, scale: display.scale, height: sign.size.height)
        let changed = try #require(bounds)
        #expect(button.rect.insetBy(dx: -1, dy: -1).contains(changed), "changed pixels \(changed) outside the chip \(button.rect)")
        #expect(changed.minX > button.rect.midX, "only the icon at the chip's right end changes")
    }

    @Test("A value wider than the sign is shortened on screen, never wider than the sign; the whole value is copied")
    func longValue() throws {
        let value = String(repeating: "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl ", count: 4)
            .trimmingCharacters(in: .whitespaces)
        let sign = try render("Paste {{\(value)}}")
        let button = try #require(sign.copyButtons.first)
        #expect(button.value == value)
        #expect(sign.size.width <= display.frame.width * ArrowMetrics.maximumSignWidthShare + 1)
        #expect(CGRect(origin: .zero, size: sign.size).contains(button.rect))
    }

    @Test("A click on a chip is a copy, elsewhere on the sign it still ends the arrow")
    func regionKnowsChips() throws {
        let sign = try render("Code {{482913}}")
        let layout = OverlayLayout.plan(OverlayLayout.Request(
            target: .point(CGPoint(x: 300, y: 250)), display: display, signSize: sign.size,
            style: .arrow, size: .medium, forced: .bottomRight
        ))
        let flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: display.frame.height)
        let region = ClickRegion(layout: layout, flip: flip, copyButtons: sign.copyButtons.map(\.rect))
        let chip = region.copyButtons[0]
        #expect(region.contains(CGPoint(x: chip.midX, y: chip.midY)))
        #expect(region.copyButton(at: CGPoint(x: chip.midX, y: chip.midY)) == 0)
        #expect(region.copyButton(at: CGPoint(x: region.sign.minX + 8, y: region.sign.midY)) == nil)
        #expect(region.contains(CGPoint(x: region.sign.minX + 8, y: region.sign.midY)))
    }

    @Test("The CLI reports every chip in global points and rejects unbalanced braces with exit 2")
    func cli() throws {
        let dryRun = try BigArrowProcess.run(["point", "--at", "700,300", "--text", "Copy {{abc}} or {{def}}", "--dry-run", "--json"])
        #expect(dryRun.code == 0, "\(dryRun.stderr)")
        let json = try dryRun.json()
        let sign = try #require(json["sign"] as? [Double])
        let chips = try #require(json["copyButtons"] as? [[Double]])
        #expect(chips.count == 2)
        let signRect = CGRect(x: sign[0], y: sign[1], width: sign[2], height: sign[3])
        #expect(chips.allSatisfy { signRect.contains(CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3])) })
        let bad = try BigArrowProcess.run(["point", "--at", "700,300", "--text", "Copy {{abc", "--dry-run"])
        #expect(bad.code == 2)
        #expect(bad.stderr.contains("{{value}}"))
    }

    /// The bounding box, in the sign's bottom-left points, of the pixels that differ between two images.
    static func differingBounds(_ first: CGImage, _ second: CGImage, scale: CGFloat, height: CGFloat) throws -> CGRect? {
        let (a, b) = (try rgba(first), try rgba(second))
        var box: CGRect?
        let differs = { (index: Int) in (0..<4).contains { a[index * 4 + $0] != b[index * 4 + $0] } }
        for y in 0..<first.height {
            for x in 0..<first.width where differs(y * first.width + x) {
                let point = CGRect(x: CGFloat(x) / scale, y: height - CGFloat(y + 1) / scale, width: 1 / scale, height: 1 / scale)
                box = box?.union(point) ?? point
            }
        }
        return box
    }

    /// Rows top to bottom, as the image is stored.
    static func rgba(_ image: CGImage) throws -> [UInt8] {
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let data = try #require(context.data)
        return Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: image.width * image.height * 4))
    }
}
