import AppKit
import BigArrowCore

/// A row that holds a value: `field`, `code`, `link` and `totp`. The value with copy (and
/// reveal, open) buttons; a masked value shows dots until the eye reveals it for a while.
@MainActor
final class ValueRowView: NSView {
    let row: CardRow
    let style: CardStyle
    let events: CardEvents
    let valueLabel: NSTextField
    private var revealed = false
    private var eye: ActionButton?
    private var copyButton: ActionButton?
    private var timer: Timer?
    private var totp: TOTP?
    private let detail = CardStyle.label("", font: CardStyle.detailFont, color: .secondaryLabelColor)

    static let dots = String(repeating: "\u{2022}", count: 10)
    static let revealSeconds: TimeInterval = 10

    init(row: CardRow, style: CardStyle, events: CardEvents) throws {
        self.row = row
        self.style = style
        self.events = events
        let font = row.type == .totp ? CardStyle.bigCodeFont : (row.type == .code ? CardStyle.codeFont : CardStyle.valueFont)
        valueLabel = CardStyle.label("", font: font, width: CardStyle.contentWidth - CardStyle.iconButton * 2 - 12)
        super.init(frame: .zero)
        if row.type == .totp { totp = try TOTP(seed: row.value ?? "") }
        configureValue()
        build()
        refresh()
        if totp != nil { startClock() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    func configureValue() {
        valueLabel.isSelectable = !row.isMasked && totp == nil
        if row.type != .code {
            valueLabel.maximumNumberOfLines = 1
            valueLabel.lineBreakMode = .byTruncatingMiddle
            valueLabel.cell?.truncatesLastVisibleLine = true
        }
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    func build() {
        var buttons: [NSView] = []
        if row.isMasked {
            let eye = ActionButton(icon: .eye, tint: style.tint, tooltip: "Show \(row.name)") { [weak self] in self?.toggleReveal() }
            self.eye = eye
            buttons.append(eye)
        }
        if row.type == .link, let url = row.url {
            buttons.append(ActionButton(icon: .externalLink, tint: style.tint, tooltip: "Open \(row.name)") { [weak self] in
                self?.events.open(url)
            })
        }
        let copy = ActionButton(icon: .copy, tint: style.tint, tooltip: "Copy \(row.name)") { [weak self] in self?.copyValue() }
        copyButton = copy
        buttons.append(copy)
        let line = Stack.horizontal([valueLabel, NSView()] + buttons, spacing: 4)
        line.alignment = row.type == .code ? .top : .centerY
        var parts: [NSView] = []
        if let label = row.label {
            parts.append(CardStyle.label(label, font: CardStyle.labelFont, color: .secondaryLabelColor))
        }
        parts.append(line)
        if totp != nil { parts.append(detail) }
        let stack = Stack.vertical(parts, spacing: 4)
        RowLayout.fill(self, with: stack)
        line.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    /// The value as it should read now: dots, the TOTP code, or the value itself.
    var shownValue: String {
        if let totp { return Self.grouped(totp.code(at: Date())) }
        if row.isMasked, !revealed { return Self.dots }
        guard row.type == .link else { return row.value ?? "" }
        return Self.readable(row.url ?? "")
    }

    /// A link without its `https://` (and a trailing slash), as people read it.
    static func readable(_ url: String) -> String {
        var text = url
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        return text.hasSuffix("/") ? String(text.dropLast()) : text
    }

    func refresh() {
        valueLabel.stringValue = shownValue
        if let totp {
            detail.stringValue = "New code in \(Int(ceil(totp.remaining(at: Date())))) s"
        }
    }

    func copyValue() {
        let value = totp.map { $0.code(at: Date()) } ?? (row.type == .link ? row.url : row.value) ?? ""
        events.copy(row, value)
        copyButton?.flash(.check, back: .copy)
        if let copyButton {
            CardMotion.pop(copyButton)
            CardMotion.toast(row.isMasked || totp != nil ? "Copied, gone in 30 s" : "Copied", above: copyButton, style: style)
        }
        CardMotion.flash(self, color: style.tint)
        if let point = row.point { events.activate(point, row.name) }
    }

    func toggleReveal() {
        revealed.toggle()
        eye?.image = CardStyle.icon(revealed ? .eyeOff : .eye)
        if let eye { CardMotion.pop(eye) }
        refresh()
        guard revealed else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.revealSeconds) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.revealed else { return }
                self.toggleReveal()
            }
        }
    }

    func startClock() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// "482913" reads as "482 913", like authenticator apps show it.
    static func grouped(_ code: String) -> String {
        guard code.count == 6 else { return code }
        return "\(code.prefix(3)) \(code.suffix(3))"
    }

    override func removeFromSuperview() {
        timer?.invalidate()
        super.removeFromSuperview()
    }
}

/// Pins a row's content to its edges, with an inset left and right.
@MainActor
enum RowLayout {
    static func fill(_ container: NSView, with content: NSView, horizontal inset: CGFloat = 0) {
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}
