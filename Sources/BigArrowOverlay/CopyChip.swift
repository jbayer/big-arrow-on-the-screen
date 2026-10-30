import AppKit
import BigArrowCore

/// One `{{value}}` of the sign: the value in a bold monospaced font and Feather's copy icon on a
/// rounded chip, inline in the sentence. It looks like the close button: filled with the text
/// colour, value and icon in the arrow colour. A value wider than the sign is shown with a middle
/// ellipsis; the whole value is copied.
struct CopyChip {
    let value: String
    let fontSize: CGFloat
    let maxWidth: CGFloat
    let appearance: SignAppearance

    /// Shares of the sign's font size.
    static let valueShare: CGFloat = 0.78
    static let heightShare: CGFloat = 1.12
    static let paddingShare: CGFloat = 0.36
    static let gapShare: CGFloat = 0.28
    static let iconShare: CGFloat = 0.74

    var valueFont: NSFont { NSFont.monospacedSystemFont(ofSize: (fontSize * Self.valueShare).rounded(), weight: .bold) }
    var height: CGFloat { ceil(fontSize * Self.heightShare) }
    var padding: CGFloat { (fontSize * Self.paddingShare).rounded() }
    var iconSize: CGFloat { (fontSize * Self.iconShare).rounded() }
    var gap: CGFloat { (fontSize * Self.gapShare).rounded() }

    var valueWidth: CGFloat {
        let natural = ceil(NSAttributedString(string: value, attributes: [.font: valueFont]).size().width)
        return min(natural, maxWidth - padding * 2 - gap - iconSize)
    }

    var size: CGSize { CGSize(width: padding * 2 + valueWidth + gap + iconSize, height: height) }

    /// The chip as a text attachment, centred on the cap height of the sign's font.
    func attachment(icon: FeatherIcon, font: NSFont, scale: CGFloat) -> NSTextAttachment {
        let attachment = NSTextAttachment()
        attachment.image = NSImage(cgImage: image(icon: icon, scale: scale), size: size)
        attachment.bounds = CGRect(x: 0, y: ((font.capHeight - height) / 2).rounded(), width: size.width, height: size.height)
        return attachment
    }

    func image(icon: FeatherIcon, scale: CGFloat) -> CGImage {
        Canvas(size: size, scale: scale).render { context in
            let shape = CGRect(origin: .zero, size: size)
            let corner = appearance.corners == .round ? height / 2 : height * 0.18
            context.addPath(CGPath(roundedRect: shape, cornerWidth: corner, cornerHeight: corner, transform: nil))
            context.setFillColor(appearance.textTint.cgColor)
            context.fillPath()
            drawValue(in: context)
            drawIcon(icon, in: context, at: CGPoint(x: padding + valueWidth + gap, y: (height - iconSize) / 2))
        }
    }

    func drawValue(in context: CGContext) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingMiddle
        let string = NSAttributedString(string: value, attributes: [
            .font: valueFont, .paragraphStyle: paragraph, .foregroundColor: Self.nsColor(appearance.color)
        ])
        let lineHeight = ceil(valueFont.ascender - valueFont.descender)
        let rect = CGRect(x: padding, y: ((height - lineHeight) / 2).rounded(), width: valueWidth, height: lineHeight)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        string.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
        NSGraphicsContext.restoreGraphicsState()
    }

    /// Feather's 24-unit, y-down outline scaled into the icon square and stroked like the original.
    func drawIcon(_ icon: FeatherIcon, in context: CGContext, at origin: CGPoint) {
        let unit = iconSize / FeatherIcon.viewBox
        var transform = CGAffineTransform(translationX: origin.x, y: origin.y + iconSize).scaledBy(x: unit, y: -unit)
        guard let path = icon.path.copy(using: &transform) else { return }
        context.addPath(path)
        context.setStrokeColor(appearance.color.cgColor)
        context.setLineWidth(FeatherIcon.strokeWidth * unit * 1.15)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.strokePath()
    }

    static func nsColor(_ color: ArrowColor) -> NSColor {
        NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }
}
