import Foundation

/// What a row of a cue card is. Every kind needs its own fields, checked by `CardRow.validate`.
public enum CardRowKind: String, Codable, CaseIterable, Sendable {
    case text, field, code, link, totp, qr, image, file, choice, input, checklist, progress, actions

    /// Rows whose answer ends the card.
    public var answers: Bool { [.choice, .input, .checklist, .actions].contains(self) }
}

/// One option, button or checklist item.
public struct CardItem: Codable, Equatable, Sendable {
    public let id: String
    public let label: String
    public var detail: String?
    /// Buttons only: `primary` is filled in the card colour, `plain` is outlined.
    public var style: String?
    /// Checklist items only: where the arrow points while this item is the next one.
    public var point: CardPoint?

    public init(id: String, label: String) {
        self.id = id
        self.label = label
    }

    static let keys: Set<String> = ["id", "label", "detail", "style", "point"]
}

/// One row of a cue card. A flat record: `type` says which of the optional fields it uses.
public struct CardRow: Codable, Equatable, Sendable {
    public let type: CardRowKind
    public var id: String?
    public var label: String?
    public var value: String?
    /// A secret source (`pass:`, `keychain:`, `op:`, `env:`, `file:`), resolved into `value` before showing.
    public var secret: String?
    /// Shown as dots until the human reveals it, copied as a concealed clipboard item.
    public var masked: Bool?
    public var url: String?
    public var path: String?
    public var items: [CardItem]?
    public var multiline: Bool?
    public var progress: Double?
    /// Where the arrow points while this row is the active one.
    public var point: CardPoint?

    public init(type: CardRowKind) {
        self.type = type
    }

    static let keys: Set<String> = [
        "type", "id", "label", "value", "secret", "masked", "url", "path", "items", "multiline", "progress", "point"
    ]

    public var isMasked: Bool { masked == true || (secret != nil && type != .totp) }

    /// The label a reply names this row by, never its value.
    public var name: String { label ?? id ?? type.rawValue }

    /// The value a copy button copies; nil when the row has none.
    public var copyValue: String? {
        switch type {
        case .field, .code, .qr: value
        case .link: url
        default: nil
        }
    }

    /// Checks that the row has what its kind needs. `index` is 1-based, for the message.
    public func validate(index: Int) throws {
        let problem = missing()
        if let problem { throw BigArrowError.badInput("card row \(index) (\(type.rawValue)): \(problem)") }
        if let progress, !(0...1).contains(progress) {
            throw BigArrowError.badInput("card row \(index) (progress): progress must be between 0 and 1")
        }
    }

    func missing() -> String? {
        let hasValue = !(value ?? "").isEmpty || secret != nil
        switch type {
        case .text, .code, .qr: return hasValue ? nil : "needs a value"
        case .field: return label == nil ? "needs a label" : (hasValue ? nil : "needs a value or a secret")
        case .totp: return hasValue ? nil : "needs the seed as secret (file:, pass:, keychain:, op:, env:)"
        case .link: return url.flatMap(URL.init(string:))?.scheme == nil ? "needs a url with a scheme, like https://" : nil
        case .image, .file: return path == nil ? "needs a path" : nil
        case .choice: return (2...6).contains(items?.count ?? 0) ? nil : "needs 2 to 6 items"
        case .actions: return (1...4).contains(items?.count ?? 0) ? nil : "needs 1 to 4 items (buttons)"
        case .checklist: return (items ?? []).isEmpty ? "needs at least one item" : nil
        case .input: return label == nil ? "needs a label (the question)" : nil
        case .progress: return progress == nil && value == nil ? "needs progress (0 to 1) or a value" : nil
        }
    }
}
