import AppKit
import BigArrowCore

/// The sign's sentence laid out once with TextKit: its size, its lines and where every copy chip
/// landed. Drawing uses the same layout, so a chip's click area is exactly where it is drawn.
struct SignTextLayout {
    let size: CGSize
    let lines: Int
    /// Each chip in top-left points of the text block, in reading order.
    let chips: [CGRect]
    private let manager: NSLayoutManager
    private let storage: NSTextStorage
    private let origin: CGPoint

    /// Lays out `text` in at most `maxWidth`, centred, `copied` showing a check instead of the copy icon.
    init(_ text: SignText, style: Style, maxWidth: CGFloat, copied: Int? = nil) {
        storage = NSTextStorage(attributedString: style.string(text, maxWidth: maxWidth, copied: copied))
        manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        let used = manager.usedRect(for: container)
        origin = used.origin
        size = CGSize(width: ceil(used.width), height: ceil(used.height))
        var count = 0
        manager.enumerateLineFragments(forGlyphRange: manager.glyphRange(for: container)) { _, _, _, _, _ in count += 1 }
        lines = max(1, count)
        chips = Self.chipRects(manager, storage: storage, origin: used.origin)
    }

    /// Draws into `rect`, bottom-left points of the sign.
    func draw(in context: CGContext, rect: CGRect) {
        context.saveGState()
        context.translateBy(x: rect.minX - origin.x, y: rect.maxY + origin.y)
        context.scaleBy(x: 1, y: -1)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)
        manager.drawGlyphs(forGlyphRange: manager.glyphRange(for: manager.textContainers[0]), at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        context.restoreGState()
    }

    static func chipRects(_ manager: NSLayoutManager, storage: NSTextStorage, origin: CGPoint) -> [CGRect] {
        var rects: [CGRect] = []
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            let glyph = manager.glyphIndexForCharacter(at: range.location)
            let line = manager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            let location = manager.location(forGlyphAt: glyph)
            let bounds = attachment.bounds
            let baseline = line.minY + location.y - origin.y
            rects.append(CGRect(
                x: line.minX + location.x - origin.x, y: baseline - bounds.maxY, width: bounds.width, height: bounds.height
            ))
        }
        return rects
    }

    /// Font, colour and chip look of one sign at one font size.
    struct Style {
        let fontSize: CGFloat
        let appearance: SignAppearance
        let scale: CGFloat

        func string(_ text: SignText, maxWidth: CGFloat, copied: Int?) -> NSAttributedString {
            let font = SignRenderer.font(fontSize)
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            paragraph.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font, .paragraphStyle: paragraph, .foregroundColor: CopyChip.nsColor(appearance.textTint)
            ]
            let result = NSMutableAttributedString()
            var chip = 0
            for segment in text.segments {
                switch segment {
                case .plain(let plain):
                    result.append(NSAttributedString(string: plain, attributes: attributes))
                case .copy(let value):
                    let look = CopyChip(value: value, fontSize: fontSize, maxWidth: maxWidth, appearance: appearance)
                    let attachment = look.attachment(icon: chip == copied ? .check : .copy, font: font, scale: scale)
                    let piece = NSMutableAttributedString(attachment: attachment)
                    piece.addAttributes(attributes, range: NSRange(location: 0, length: piece.length))
                    result.append(piece)
                    chip += 1
                }
            }
            return result
        }
    }
}
