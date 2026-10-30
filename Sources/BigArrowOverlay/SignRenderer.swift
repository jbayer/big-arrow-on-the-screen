import AppKit
import BigArrowCore

/// The sign: a pill (or square) in the arrow colour with its border (see `ArrowBorder`), heavy
/// rounded text with a copy chip for every `{{value}}`, and with `--close-button` an X in its
/// right end. Edge, body and text are separate images: the thin black edge goes below every white
/// border of the arrow, so it never cuts through the white where the shaft meets the sign, and the
/// arrow's root is drawn between body and text, so it blends into the body and never covers a letter.
public struct SignImage: @unchecked Sendable {
    public let edge: CGImage
    public let body: CGImage
    public let text: CGImage
    /// Size in points.
    public let size: CGSize
    public let fontSize: CGFloat
    public let lines: Int
    public var copyButtons: [CopyButton] = []
}

/// A chip in the sign: where it is (bottom-left points of the sign), what a click copies, and the
/// sign's text image with this chip showing a check, shown for a moment after the click.
public struct CopyButton: @unchecked Sendable {
    public let rect: CGRect
    public let value: String
    public let copiedText: CGImage
}

public enum SignRenderer {
    static let paddingX: CGFloat = 30
    static let paddingY: CGFloat = 16
    static let outline: CGFloat = 3.5
    /// The thin black line of `--border white-black` and `black`, as wide as the arrow's per side.
    static let edge: CGFloat = 1.5
    static let seamOverlap: CGFloat = 0.5
    /// The X: its diameter as a share of the font size (at least the minimum, an easy target),
    /// the gap after the text, and its margin to the sign's edge. On a one-line pill it sits
    /// almost concentric with the rounded end.
    static let crossShare: CGFloat = 0.8
    static let crossMinimum: CGFloat = 26
    static let crossGap: CGFloat = 12
    static let crossMargin: CGFloat = 20

    /// Lays out the text, then draws edge, body and text, and one text image per copy chip with
    /// that chip showing a check.
    public static func render(text: SignText, appearance: SignAppearance, display: Display) -> SignImage {
        let maxTextWidth = display.frame.width * ArrowMetrics.maximumSignWidthShare - paddingX * 2
        let (layout, style) = fit(text, appearance: appearance, display: display, maxWidth: maxTextWidth)
        let cross = appearance.closeMark == .cross ? max(crossMinimum, (style.fontSize * crossShare).rounded()) : 0
        let frame = SignFrame(text: layout.size, cross: cross)
        let (pill, textRect) = (frame.pill, frame.textRect)
        let canvas = Canvas(size: pill, scale: display.scale)
        let textImage = { (shown: SignTextLayout) in
            canvas.render { context in
                shown.draw(in: context, rect: textRect)
                guard let center = frame.crossCenter else { return }
                drawCross(in: context, center: center, diameter: cross, appearance: appearance)
            }
        }
        var image = SignImage(
            edge: canvas.render { drawEdge(in: $0, pill: pill, appearance: appearance) },
            body: canvas.render { drawBody(in: $0, pill: pill, appearance: appearance) },
            text: textImage(layout), size: pill, fontSize: style.fontSize, lines: layout.lines
        )
        image.copyButtons = zip(layout.chips, text.copyValues).enumerated().map { index, chip in
            let (rect, value) = chip
            let copied = SignTextLayout(text, style: style, maxWidth: maxTextWidth, copied: index)
            return CopyButton(
                rect: CGRect(x: textRect.minX + rect.minX, y: textRect.maxY - rect.maxY, width: rect.width, height: rect.height),
                value: value, copiedText: textImage(copied)
            )
        }
        return image
    }

    /// Shrinks the font until the text fits in `maximumLines` lines of `maxWidth`, never below the minimum.
    static func fit(
        _ text: SignText, appearance: SignAppearance, display: Display, maxWidth: CGFloat
    ) -> (SignTextLayout, SignTextLayout.Style) {
        var style = SignTextLayout.Style(fontSize: appearance.size.metrics.fontSize, appearance: appearance, scale: display.scale)
        var layout = SignTextLayout(text, style: style, maxWidth: maxWidth)
        while layout.lines > ArrowMetrics.maximumLines, style.fontSize > ArrowMetrics.minimumFontSize {
            let smaller = max(style.fontSize - 2, ArrowMetrics.minimumFontSize)
            style = SignTextLayout.Style(fontSize: smaller, appearance: appearance, scale: display.scale)
            layout = SignTextLayout(text, style: style, maxWidth: maxWidth)
        }
        return (layout, style)
    }

    /// The X button: a filled circle with the X on it, colours from `closeTint` and `closeXTint`.
    static func drawCross(in context: CGContext, center: CGPoint, diameter: CGFloat, appearance: SignAppearance) {
        let circle = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        context.setFillColor(appearance.closeTint.cgColor)
        context.fillEllipse(in: circle)
        let arm = diameter * 0.2
        context.setStrokeColor(appearance.closeXTint.cgColor)
        context.setLineWidth(max(2.5, diameter * 0.11))
        context.setLineCap(.round)
        context.strokeLineSegments(between: [
            CGPoint(x: center.x - arm, y: center.y - arm), CGPoint(x: center.x + arm, y: center.y + arm),
            CGPoint(x: center.x - arm, y: center.y + arm), CGPoint(x: center.x + arm, y: center.y - arm)
        ])
    }

    static func font(_ size: CGFloat) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: .heavy)
        guard let rounded = base.fontDescriptor.withDesign(.rounded) else { return base }
        return NSFont(descriptor: rounded, size: size) ?? base
    }

    /// A rounded rect in the sign's corner style.
    struct Pill {
        let rect: CGRect
        let corners: SignCorners
    }

    /// The thin black line of `--border white-black` and `black`; nothing for the default.
    static func drawEdge(in context: CGContext, pill: CGSize, appearance: SignAppearance) {
        let width = edgeWidth(appearance.border)
        guard width > 0 else { return }
        let shape = Pill(rect: CGRect(origin: .zero, size: pill), corners: appearance.corners)
        stroke(shape, in: context, line: (width, appearance.edgeTint), fill: nil)
    }

    /// Fill and white border, inside the edge. It overlaps the edge by half a point so no seam shows.
    static func drawBody(in context: CGContext, pill: CGSize, appearance: SignAppearance) {
        let inset = max(0, edgeWidth(appearance.border) - seamOverlap)
        let shape = Pill(rect: CGRect(origin: .zero, size: pill).insetBy(dx: inset, dy: inset), corners: appearance.corners)
        if appearance.border == .black {
            context.addPath(pillPath(shape.rect, corners: shape.corners))
            context.setFillColor(appearance.color.cgColor)
            context.fillPath()
            return
        }
        stroke(shape, in: context, line: (outline, appearance.borderTint), fill: appearance.color)
    }

    static func edgeWidth(_ border: ArrowBorder) -> CGFloat {
        border == .shadow ? 0 : edge
    }

    /// Strokes (and optionally fills) the pill with the line fully inside its rect.
    static func stroke(_ shape: Pill, in context: CGContext, line: (width: CGFloat, color: ArrowColor), fill: ArrowColor?) {
        let rect = shape.rect.insetBy(dx: line.width / 2, dy: line.width / 2)
        context.addPath(pillPath(rect, corners: shape.corners))
        context.setStrokeColor(line.color.cgColor)
        context.setLineWidth(line.width)
        if let fill {
            context.setFillColor(fill.cgColor)
            context.drawPath(using: .fillStroke)
        } else {
            context.strokePath()
        }
    }

    static func pillPath(_ rect: CGRect, corners: SignCorners) -> CGPath {
        let corner = corners.radius(height: rect.height)
        return CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    }
}

/// The pill around the text: room for the X button at the right end when there is one.
struct SignFrame {
    let pill: CGSize
    let textRect: CGRect
    let crossCenter: CGPoint?

    init(text: CGSize, cross: CGFloat) {
        let height = ceil(text.height + SignRenderer.paddingY * 2)
        let crossInset = min(height / 2, cross / 2 + SignRenderer.crossMargin)
        let trailing = cross > 0 ? SignRenderer.crossGap + cross / 2 + crossInset : SignRenderer.paddingX
        pill = CGSize(width: ceil(SignRenderer.paddingX + text.width + trailing), height: height)
        textRect = CGRect(x: SignRenderer.paddingX, y: (height - text.height) / 2, width: text.width, height: text.height)
        crossCenter = cross > 0 ? CGPoint(x: pill.width - crossInset, y: height / 2) : nil
    }
}

/// A transparent sRGB bitmap of a size in points at a backing scale.
struct Canvas {
    let size: CGSize
    let scale: CGFloat

    func render(_ draw: (CGContext) -> Void) -> CGImage {
        let width = Int(ceil(size.width * scale))
        let height = Int(ceil(size.height * scale))
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: ColorSpaces.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { preconditionFailure("cannot create a \(width)x\(height) bitmap for the sign") }
        context.scaleBy(x: scale, y: scale)
        draw(context)
        guard let image = context.makeImage() else { preconditionFailure("cannot render the sign image") }
        return image
    }
}
