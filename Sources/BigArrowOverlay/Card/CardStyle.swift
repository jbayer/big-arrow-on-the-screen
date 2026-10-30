import AppKit
import BigArrowCore

/// Sizes, fonts and colours of a cue card. Nothing is smaller than 16 pt. The header is the
/// arrow's sign grown up: the card colour with the contrast text and the same X button.
@MainActor
public struct CardStyle {
    public let color: ArrowColor

    public static let width: CGFloat = 440
    static let padding: CGFloat = 22
    static let rowSpacing: CGFloat = 20
    static let corner: CGFloat = 18
    static let border: CGFloat = 3.5
    static let iconButton: CGFloat = 34
    static let iconSize: CGFloat = 20
    static let accentWidth: CGFloat = 5
    static let maximumHeightShare: CGFloat = 0.8

    public init(color: ArrowColor) {
        self.color = color
    }

    var tint: NSColor { Self.nsColor(color) }
    var onTint: NSColor { Self.nsColor(color.contrast) }

    static func nsColor(_ color: ArrowColor) -> NSColor {
        NSColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: 1)
    }

    /// The sign's own font: SF Pro Rounded Heavy, at the small sign's size.
    static let titleFont = SignRenderer.font(ArrowSize.small.metrics.fontSize)
    static let labelFont = NSFont.systemFont(ofSize: 16, weight: .semibold)
    static let bodyFont = NSFont.systemFont(ofSize: 18, weight: .regular)
    static let valueFont = NSFont.monospacedSystemFont(ofSize: 18, weight: .medium)
    static let codeFont = NSFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    static let bigCodeFont = NSFont.monospacedDigitSystemFont(ofSize: 34, weight: .bold)
    static let buttonFont = NSFont.systemFont(ofSize: 17, weight: .semibold)
    static let detailFont = NSFont.systemFont(ofSize: 16, weight: .regular)

    /// A Feather icon as a template image, stroked like the original.
    static func icon(_ icon: FeatherIcon, size: CGFloat = iconSize) -> NSImage {
        let image = NSImage(size: CGSize(width: size, height: size), flipped: true) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let unit = rect.width / FeatherIcon.viewBox
            var transform = CGAffineTransform(scaleX: unit, y: unit)
            guard let path = icon.path.copy(using: &transform) else { return false }
            context.addPath(path)
            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(FeatherIcon.strokeWidth * unit * 1.1)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            context.strokePath()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// The width of a row's content between the card's side paddings.
    static let contentWidth = width - padding * 2

    static func label(_ text: String, font: NSFont, color: NSColor = .labelColor, width: CGFloat = contentWidth) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = font
        field.textColor = color
        field.isSelectable = false
        field.preferredMaxLayoutWidth = width
        return field
    }

    /// Inline Markdown (bold, italic, code, links); plain text when it does not parse.
    static func markdown(_ text: String, font: NSFont) -> NSAttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let parsed = try? NSMutableAttributedString(markdown: Data(text.utf8), options: options) else {
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.labelColor])
        }
        let range = NSRange(location: 0, length: parsed.length)
        parsed.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        parsed.addAttribute(.font, value: font, range: range)
        parsed.enumerateAttribute(.inlinePresentationIntent, in: range) { value, part, _ in
            guard let raw = (value as? NSNumber)?.uintValue else { return }
            parsed.addAttribute(.font, value: styled(font, intent: InlinePresentationIntent(rawValue: raw)), range: part)
        }
        return parsed
    }

    static func styled(_ font: NSFont, intent: InlinePresentationIntent) -> NSFont {
        if intent.contains(.code) { return NSFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular) }
        var traits: NSFontDescriptor.SymbolicTraits = []
        if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
        if intent.contains(.emphasized) { traits.insert(.italic) }
        return NSFont(descriptor: font.fontDescriptor.withSymbolicTraits(traits), size: font.pointSize) ?? font
    }
}
