import Foundation

/// A cue card: a floating window with a title and rows of values, actions and questions.
/// Read as JSON (a file or stdin) or built from `bigarrow card` flags. It has no time limit:
/// only the human's click on its X closes it (or `bigarrow stop --pid`).
public struct CardDocument: Codable, Equatable, Sendable {
    public var title: String
    public var rows: [CardRow]
    /// `App` or `App:window or tab title`: the card sits beside it and row arrows look in it.
    public var app: String?
    /// The card's colour, same names as `--color`; red by default.
    public var color: String?
    /// auto, light or dark.
    public var theme: String?
    public var say: Bool?
    /// Stay up after every question is answered, until the X. By default a card closes itself
    /// once its last question (buttons, choice, text field, checklist) is answered.
    public var keep: Bool?

    public init(title: String, rows: [CardRow]) {
        self.title = title
        self.rows = rows
    }

    static let keys: Set<String> = ["title", "rows", "app", "color", "theme", "say", "keep"]

    /// The rows that ask something, by index.
    public var questions: [Int] { rows.indices.filter { rows[$0].type.answers } }
    public static let themes = ["auto", "light", "dark"]

    public var hasSecret: Bool { rows.contains { $0.isMasked || $0.type == .totp } }

    /// Parses and validates; unknown keys are an error, so a typo never silently drops a row.
    public static func parse(_ data: Data) throws -> CardDocument {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw BigArrowError.badInput("the card is not valid JSON: \(error.localizedDescription)")
        }
        try CardKeyCheck.check(object)
        let document: CardDocument
        do {
            document = try JSONDecoder().decode(CardDocument.self, from: data)
        } catch let error as DecodingError {
            throw BigArrowError.badInput("the card does not match the format: \(CardKeyCheck.describe(error))")
        }
        try document.validate()
        return document
    }

    public func validate() throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BigArrowError.badInput("the card needs a title: one sentence that says what the human should do")
        }
        guard !rows.isEmpty else { throw BigArrowError.badInput("the card needs at least one row") }
        for (index, row) in rows.enumerated() { try row.validate(index: index + 1) }
        if let theme, !Self.themes.contains(theme) {
            throw BigArrowError.badInput("theme '\(theme)' is not one of \(Self.themes.joined(separator: ", "))")
        }
        let ids = rows.flatMap { $0.items ?? [] }.map(\.id)
        if let twice = Dictionary(grouping: ids, by: { $0 }).first(where: { $0.value.count > 1 })?.key {
            throw BigArrowError.badInput("item id '\(twice)' is used twice; ids name the answer in the reply")
        }
    }

    public func encoded() -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(self)
        } catch {
            preconditionFailure("a validated card always encodes: \(error)")
        }
    }

    /// The same card with every secret value replaced, for anything printed or written to disk.
    public var redacted: CardDocument {
        var copy = self
        copy.rows = rows.map { row in
            var row = row
            if row.isMasked || row.type == .totp, row.value != nil { row.value = CardDocument.redaction }
            return row
        }
        return copy
    }

    public static let redaction = "<secret>"
}

/// Rejects keys the format does not know, with the path of the first one.
enum CardKeyCheck {
    static func check(_ object: Any) throws {
        guard let card = object as? [String: Any] else { throw BigArrowError.badInput("the card must be a JSON object") }
        try unknown(card, CardDocument.keys, at: "card")
        for (index, row) in (card["rows"] as? [[String: Any]] ?? []).enumerated() {
            let place = "row \(index + 1)"
            try unknown(row, CardRow.keys, at: place)
            if let point = row["point"] as? [String: Any] { try unknown(point, CardPoint.keys, at: "\(place) point") }
            for item in row["items"] as? [[String: Any]] ?? [] {
                try unknown(item, CardItem.keys, at: "\(place) item")
                if let point = item["point"] as? [String: Any] { try unknown(point, CardPoint.keys, at: "\(place) item point") }
            }
        }
    }

    static func unknown(_ object: [String: Any], _ known: Set<String>, at place: String) throws {
        let extra = Set(object.keys).subtracting(known).sorted()
        guard extra.isEmpty else {
            throw BigArrowError.badInput("\(place): unknown key '\(extra[0])', known: \(known.sorted().joined(separator: ", "))")
        }
    }

    static func describe(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(_, let context), .valueNotFound(_, let context), .keyNotFound(_, let context), .dataCorrupted(let context):
            let path = context.codingPath.map { $0.intValue.map { "\($0 + 1)" } ?? $0.stringValue }.joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}
