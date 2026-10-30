import AppKit
import BigArrowCore

/// The whole card: the header in the card colour (title and X), then the rows on the system's
/// window background, light or dark. Taller than the screen allows, the rows scroll.
@MainActor
public final class CardView: NSView {
    public let document: CardDocument
    let style: CardStyle
    let events: CardEvents
    private(set) var rows: [RowContainer] = []
    private var body: NSStackView?

    public init(document: CardDocument, color: ArrowColor, events: CardEvents, maxHeight: CGFloat) throws {
        self.document = document
        self.style = CardStyle(color: color)
        self.events = events
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = CardStyle.corner
        layer?.masksToBounds = true
        // The sign's border: its contrast colour (white on dark colours) all round.
        layer?.borderWidth = CardStyle.border
        layer?.borderColor = style.onTint.cgColor
        rows = try document.rows.map { row in
            RowContainer(row: row, content: try RowFactory.view(for: row, style: style, events: events), style: style, events: events)
        }
        try build(maxHeight: maxHeight)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    func build(maxHeight: CGFloat) throws {
        let header = CardHeader(title: document.title, style: style) { [events] in events.close() }
        let body = Stack.vertical(rows, spacing: CardStyle.rowSpacing)
        body.edgeInsets = NSEdgeInsets(top: 22, left: 0, bottom: 24, right: 0)
        rows.forEach { $0.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true }
        self.body = body
        let content = Stack.vertical([header, scrolling(body, maxHeight: maxHeight - header.fittingSize.height)], spacing: 0)
        content.arrangedSubviews.forEach { $0.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true }
        RowLayout.fill(self, with: content)
        widthAnchor.constraint(equalToConstant: CardStyle.width).isActive = true
    }

    /// The rows as they are, or in a scroll view when they are taller than `maxHeight`.
    func scrolling(_ body: NSStackView, maxHeight: CGFloat) -> NSView {
        body.translatesAutoresizingMaskIntoConstraints = false
        body.widthAnchor.constraint(equalToConstant: CardStyle.width).isActive = true
        let height = body.fittingSize.height
        guard height > maxHeight else { return body }
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.documentView = body
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.heightAnchor.constraint(equalToConstant: max(120, maxHeight)).isActive = true
        return scroll
    }

    /// Every button and text field with its label, in the card's top-left points, in reading order.
    public func controls() -> [CardControl] {
        layoutSubtreeIfNeeded()
        return Self.controlViews(in: self).map { control in
            let rect = convert(control.bounds, from: control)
            let topLeft = CGRect(x: rect.minX, y: bounds.height - rect.maxY, width: rect.width, height: rect.height)
            let name = control.accessibilityLabel() ?? (control as? NSTextField)?.placeholderString ?? "control"
            return CardControl(name: name, rect: topLeft)
        }
    }

    static func controlViews(in view: NSView) -> [NSView] {
        view.subviews.flatMap { sub -> [NSView] in
            let isControl = sub is ActionButton || sub is PillButton || sub is OptionView || (sub as? NSTextField)?.isEditable == true
            return isControl ? [sub] : controlViews(in: sub)
        }
    }

    /// A question answered: its buttons, options and field dim and stop answering, the pick
    /// fills and pops. Copy buttons keep working.
    public func markRowAnswered(_ index: Int, chosen: String?) {
        guard rows.indices.contains(index) else { return }
        for control in Self.controlViews(in: rows[index]) where control is PillButton || control is OptionView || control is NSTextField {
            let picked = chosen != nil && control.accessibilityLabel() == chosen
            control.alphaValue = picked ? 1 : 0.35
            (control as? NSTextField)?.isEnabled = false
            (control as? PillButton)?.isAnswerable = false
            (control as? OptionView)?.isAnswerable = false
            guard picked else { continue }
            (control as? OptionView)?.markChosen()
            (control as? PillButton)?.markChosen()
            CardMotion.pop(control)
        }
    }

    /// With `keep`, once everything is answered: a banner in the card colour at the bottom.
    public func showSent(_ text: String) {
        guard let body else { return }
        let banner = SentBanner(text: text, style: style)
        let row = NSView()
        RowLayout.fill(row, with: banner, horizontal: CardStyle.padding)
        body.addArrangedSubview(row)
        row.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        DispatchQueue.main.async { CardMotion.enter(banner) }
    }

    /// Marks the row (or the checklist holding the item) the arrow points from.
    public func markActive(_ name: String?) {
        for row in rows { row.setActive(name != nil && row.names.contains(name ?? "")) }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsLayout = true
    }

    public override func layout() {
        super.layout()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        }
    }
}

/// One row with the card's side padding and an accent bar while its arrow is shown. A click on a
/// row that points somewhere shows that arrow.
@MainActor
final class RowContainer: NSView {
    let row: CardRow
    let events: CardEvents
    let accent = NSView()

    init(row: CardRow, content: NSView, style: CardStyle, events: CardEvents) {
        self.row = row
        self.events = events
        super.init(frame: .zero)
        accent.wantsLayer = true
        accent.layer?.backgroundColor = style.tint.cgColor
        accent.layer?.cornerRadius = CardStyle.accentWidth / 2
        accent.isHidden = true
        RowLayout.fill(self, with: content, horizontal: CardStyle.padding)
        accent.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accent)
        NSLayoutConstraint.activate([
            accent.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 7),
            accent.widthAnchor.constraint(equalToConstant: CardStyle.accentWidth),
            accent.topAnchor.constraint(equalTo: topAnchor),
            accent.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    /// The row's own name and its checklist items' labels, as `activate` names them.
    var names: [String] { [row.name] + (row.items ?? []).map(\.label) }

    func setActive(_ active: Bool) {
        accent.isHidden = !active
    }

    override var mouseDownCanMoveWindow: Bool { row.point == nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let point = row.point else { return super.mouseDown(with: event) }
        events.activate(point, row.name)
    }
}
