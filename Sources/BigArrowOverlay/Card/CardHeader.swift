import AppKit
import BigArrowCore

/// The card colour band: the title set like the arrow's sign (rounded heavy, centred, the
/// contrast colour), with the X in the top right corner and as much room on the left, so the
/// title stays centred.
@MainActor
final class CardHeader: NSView {
    static let vertical: CGFloat = 20
    static let corner: CGFloat = 12

    init(title: String, style: CardStyle, close: @escaping () -> Void) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = style.tint.cgColor
        let side = Self.corner + CardStyle.iconButton + 10
        let label = CardStyle.label("", font: CardStyle.titleFont, width: CardStyle.width - side * 2)
        label.attributedStringValue = Self.title(title, color: style.onTint)
        let button = ActionButton(icon: .close, tint: style.tint, tooltip: "Close") { close() }
        button.wantsLayer = true
        button.layer?.cornerRadius = CardStyle.iconButton / 2
        button.layer?.backgroundColor = style.onTint.cgColor
        [label, button].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: side),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -side),
            label.topAnchor.constraint(equalTo: topAnchor, constant: Self.vertical),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Self.vertical),
            button.topAnchor.constraint(equalTo: topAnchor, constant: Self.corner),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.corner)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    /// Centred, as on the sign.
    static func title(_ text: String, color: NSColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakStrategy = .standard
        return NSAttributedString(string: text, attributes: [
            .font: CardStyle.titleFont, .foregroundColor: color, .paragraphStyle: paragraph
        ])
    }
}

/// "Sent" after the last answer of a `keep` card: the contrast text centred on a rounded band
/// of the card colour, with Feather's check.
@MainActor
final class SentBanner: NSView {
    init(text: String, style: CardStyle) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = style.tint.cgColor
        layer?.cornerRadius = 12
        let icon = NSImageView(image: CardStyle.icon(.check))
        icon.contentTintColor = style.onTint
        let label = CardStyle.label(text, font: CardStyle.buttonFont, color: style.onTint, width: CardStyle.contentWidth - 80)
        let line = Stack.horizontal([icon, label], spacing: 8)
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            line.centerXAnchor.constraint(equalTo: centerXAnchor),
            line.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            line.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            line.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 12)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }
}
