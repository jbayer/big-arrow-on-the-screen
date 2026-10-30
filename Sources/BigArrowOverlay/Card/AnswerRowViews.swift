import AppKit
import BigArrowCore

/// Rows that answer the card: `actions` (buttons in a line), `choice` (one full-width button per
/// option, with its detail), `input` (a text field with Send) and `checklist`.
@MainActor
enum AnswerRows {
    static func actions(_ row: CardRow, style: CardStyle, events: CardEvents) -> NSView {
        let items = row.items ?? []
        let buttons = items.enumerated().map { index, item in
            let primary = item.style.map { $0 == "primary" } ?? (index == items.count - 1)
            return PillButton(item.label, primary: primary, style: style) { events.answer(row, .button, item.id) }
        }
        let line = Stack.horizontal([NSView()] + buttons, spacing: 10)
        return withLabel(row.label, line)
    }

    static func choice(_ row: CardRow, style: CardStyle, events: CardEvents) -> NSView {
        let options = (row.items ?? []).map { item -> NSView in
            OptionView(item: item, style: style) { events.answer(row, .choice, item.id) }
        }
        let stack = Stack.vertical(options, spacing: 8)
        options.forEach { $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return withLabel(row.label, stack)
    }

    /// A label above the content, when the row has one.
    static func withLabel(_ label: String?, _ content: NSView) -> NSView {
        guard let label else { return content }
        let stack = Stack.vertical([CardStyle.label(label, font: CardStyle.labelFont, color: .secondaryLabelColor), content])
        content.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }
}

/// One option of a `choice` row: its label in the card colour and its detail below, in an
/// outlined box that fills with a tint under the pointer. A click answers the card.
@MainActor
final class OptionView: NSView {
    let handler: () -> Void
    let style: CardStyle
    /// False once the card is answered.
    var isAnswerable = true

    init(item: CardItem, style: CardStyle, handler: @escaping () -> Void) {
        self.handler = handler
        self.style = style
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 2
        layer?.borderColor = style.tint.cgColor
        var lines: [NSView] = [CardStyle.label(item.label, font: CardStyle.buttonFont, color: style.tint)]
        if let detail = item.detail { lines.append(CardStyle.label(detail, font: CardStyle.detailFont, color: .secondaryLabelColor)) }
        let stack = Stack.vertical(lines, spacing: 2)
        stack.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 14)
        RowLayout.fill(self, with: stack)
        setAccessibilityRole(.button)
        setAccessibilityLabel(item.label)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseUp(with event: NSEvent) {
        guard isAnswerable, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        handler()
    }

    override func mouseDown(with event: NSEvent) {
        if isAnswerable { CardMotion.press(self) }
    }

    /// The option that was picked: filled with a stronger wash and a thicker border.
    func markChosen() {
        layer?.backgroundColor = style.tint.withAlphaComponent(0.2).cgColor
        layer?.borderWidth = 3
    }

    override func mouseEntered(with event: NSEvent) {
        guard isAnswerable else { return }
        layer?.backgroundColor = style.tint.withAlphaComponent(0.12).cgColor
    }

    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }

    override func accessibilityPerformPress() -> Bool {
        handler()
        return true
    }
}

/// A question with a text field and Send. Return sends a one-line answer, Command-Return a multi-line one.
@MainActor
final class InputRowView: NSView, NSTextFieldDelegate {
    let row: CardRow
    let events: CardEvents
    let field: NSTextField

    init(row: CardRow, style: CardStyle, events: CardEvents) {
        self.row = row
        self.events = events
        field = NSTextField(string: row.value ?? "")
        super.init(frame: .zero)
        field.font = CardStyle.bodyFont
        field.placeholderString = row.multiline == true ? "Type, then Command-Return" : "Type, then Return"
        field.usesSingleLineMode = row.multiline != true
        field.cell?.wraps = row.multiline == true
        field.delegate = self
        field.setAccessibilityLabel(row.label)
        if row.multiline == true { field.heightAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true }
        let send = PillButton("Send", primary: true, style: style) { [weak self] in self?.send() }
        let question = CardStyle.label(row.label ?? "", font: CardStyle.labelFont, color: .secondaryLabelColor)
        let stack = Stack.vertical([question, field, Stack.horizontal([NSView(), send])], spacing: 8)
        field.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        stack.arrangedSubviews[2].widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        RowLayout.fill(self, with: stack)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    var rowID: String { row.id ?? "input" }

    func send() {
        events.answer(row, .input, field.stringValue)
    }

    func controlTextDidChange(_ notification: Notification) {
        events.typed(rowID, field.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        let commandHeld = NSEvent.modifierFlags.contains(.command)
        if row.multiline == true, !commandHeld {
            textView.insertNewlineIgnoringFieldEditor(nil)
            return true
        }
        send()
        return true
    }
}

/// Checklist items with a tick box each. The first unticked item with a `point` gets the arrow;
/// ticking every item answers the card.
@MainActor
final class ChecklistRowView: NSView {
    let row: CardRow
    let style: CardStyle
    let events: CardEvents
    private(set) var checked: [String] = []
    private var boxes: [String: ActionButton] = [:]

    init(row: CardRow, style: CardStyle, events: CardEvents) {
        self.row = row
        self.style = style
        self.events = events
        super.init(frame: .zero)
        let lines = (row.items ?? []).map { item -> NSView in
            let box = ActionButton(icon: .square, tint: style.tint, tooltip: "Tick \(item.label)") { [weak self] in self?.toggle(item.id) }
            boxes[item.id] = box
            let text = CardStyle.label(item.label, font: CardStyle.bodyFont)
            return Stack.horizontal([box, text], spacing: 6)
        }
        RowLayout.fill(self, with: AnswerRows.withLabel(row.label, Stack.vertical(lines, spacing: 4)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    var items: [CardItem] { row.items ?? [] }

    /// The next item to do, with its arrow target.
    var next: CardItem? { items.first { !checked.contains($0.id) } }

    func toggle(_ id: String) {
        if let index = checked.firstIndex(of: id) { checked.remove(at: index) } else { checked.append(id) }
        boxes[id]?.image = CardStyle.icon(checked.contains(id) ? .checkSquare : .square)
        if let box = boxes[id] {
            CardMotion.pop(box)
            if let line = box.superview { CardMotion.flash(line, color: style.tint) }
        }
        events.checked(checked)
        if checked.count == items.count {
            events.answer(row, .checklist, nil)
        } else if let next, let point = next.point {
            events.activate(point, next.label)
        }
    }
}
