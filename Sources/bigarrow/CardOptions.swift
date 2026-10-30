import ArgumentParser
import BigArrowCore
import Foundation

/// The card's content as flags, for the common case; a JSON card can do everything.
struct CardContentOptions: ParsableArguments {
    @Argument(help: help("A JSON card file, or - to read it from stdin. Without it, the flags below build the card.", "card.json"))
    var file: String?

    @Option(help: help("The title: one sentence that says what to do ('Franz, log in to Hetzner').", "text"))
    var title: String?

    @Option(name: .customLong("note"), help: help("A line of text (inline Markdown). Repeatable.", "text"))
    var notes: [String] = []

    @Option(name: .customLong("field"), help: help("A value with a copy button: 'User=franz'. Repeatable.", "label=value"))
    var fields: [String] = []

    @Option(name: .customLong("secret"), help: help(
        "A masked value read from a source, never written on the command line: 'Password=pass:hetzner/web'. "
            + "Sources: pass:, keychain:<service>/<account>, op:, env:, file:. Repeatable.", "label=source"
    ))
    var secrets: [String] = []

    @Option(name: .customLong("code"), help: help("A command or snippet in monospace with a copy button. Repeatable.", "text"))
    var codes: [String] = []

    @Option(name: .customLong("link"), help: help("A link with open and copy buttons: 'https://...' or 'Label=https://...'.", "url"))
    var links: [String] = []

    @Option(help: help("Ask a question; the typed answer is the reply.", "question"))
    var ask: String?

    @Option(name: .customLong("choice"), help: help("An option to pick, 'id=Label' or 'Label'. Give 2 to 6.", "option"))
    var choices: [String] = []

    @Option(name: .customLong("button"), help: help("A button, 'id=Label' or 'Label'; the last one is filled. Up to 4.", "button"))
    var buttons: [String] = []

    @Option(help: help("The card sits beside this app's window and row arrows look in it: 'App' or 'App:title'.", "app[:title]"))
    var app: String?

    @Option(help: help("Card colour, as for point (default red).", "colour"))
    var color: String?

    @Option(help: help("auto, light or dark.", "theme"))
    var theme: String?

    @Flag(help: "Speak the title with macOS 'say'.")
    var say = false

    @Flag(help: "Stay up after every question is answered, until the X (default: the card closes itself then).")
    var keep = false
}

struct CardRunOptions: ParsableArguments {
    @Flag(help: "Return when the human answers or closes the card and print the reply (default: return at once, see 'wait').")
    var wait = false

    @Option(help: help("Replace the rows of the running card with this pid; what was copied, ticked and typed stays.", "pid"))
    var update: Int32?

    @Option(help: help("Render the card into this PNG instead of showing it (secrets as dots).", "file"))
    var png: String?

    @Flag(name: .customLong("dry-run"), help: "Check the card and its secret sources, print it with secrets hidden, show nothing.")
    var dryRun = false

    @Flag(help: "Errors as JSON on stderr (results are always JSON).")
    var json = false

    @Flag(name: .customLong("child"), help: .hidden)
    var child = false
}

/// Builds a card from the content flags, or reads it from a file and applies the flag overrides.
enum CardFlags {
    static func document(_ options: CardContentOptions) throws -> CardDocument {
        var document: CardDocument
        if let file = options.file {
            guard try rowFlags(options).isEmpty else {
                throw BigArrowError.badInput("give the rows either in the card file or as flags, not both")
            }
            document = try CardInput.parse(try CardInput.read(file, stdinTaken: false))
            if let title = options.title { document.title = title }
        } else {
            guard let title = options.title else { throw BigArrowError.badInput("give a card file, or --title and some rows") }
            document = CardDocument(title: title, rows: try rowFlags(options))
        }
        document.app = options.app ?? document.app
        document.color = options.color ?? document.color
        document.theme = options.theme ?? document.theme
        if options.say { document.say = true }
        if options.keep { document.keep = true }
        try document.validate()
        try document.checkSecretSources()
        if let color = document.color { _ = try ArrowColor.parse(color) }
        return document
    }

    static func rowFlags(_ options: CardContentOptions) throws -> [CardRow] {
        var rows = options.notes.map { row(.text, value: $0) }
        rows += try options.fields.map { raw in
            let (label, value) = try pair(raw, flag: "--field")
            var row = row(.field, value: value)
            row.label = label
            return row
        }
        rows += try options.secrets.map(secretRow)
        rows += options.codes.map { row(.code, value: $0) }
        rows += options.links.map(linkRow)
        if let ask = options.ask {
            var input = CardRow(type: .input)
            input.label = ask
            rows.append(input)
        }
        if !options.choices.isEmpty { rows.append(itemsRow(.choice, options.choices)) }
        if !options.buttons.isEmpty { rows.append(itemsRow(.actions, options.buttons)) }
        return rows
    }

    static func row(_ type: CardRowKind, value: String) -> CardRow {
        var row = CardRow(type: type)
        row.value = value
        return row
    }

    static func secretRow(_ raw: String) throws -> CardRow {
        let (label, source) = try pair(raw, flag: "--secret")
        _ = try SecretSource.parse(source)
        var row = CardRow(type: .field)
        row.label = label
        row.secret = source
        return row
    }

    /// `Label=https://...` or a bare URL (whose query may contain `=`).
    static func linkRow(_ raw: String) -> CardRow {
        var row = CardRow(type: .link)
        let scheme = raw.range(of: "://")
        if let equals = raw.firstIndex(of: "="), scheme.map({ equals < $0.lowerBound }) ?? true {
            row.label = String(raw[..<equals])
            row.url = String(raw[raw.index(after: equals)...])
        } else {
            row.url = raw
        }
        return row
    }

    static func itemsRow(_ type: CardRowKind, _ raws: [String]) -> CardRow {
        var row = CardRow(type: type)
        row.items = raws.map { raw in
            guard let equals = raw.firstIndex(of: "=") else { return CardItem(id: slug(raw), label: raw) }
            return CardItem(id: String(raw[..<equals]), label: String(raw[raw.index(after: equals)...]))
        }
        return row
    }

    static func pair(_ raw: String, flag: String) throws -> (String, String) {
        guard let equals = raw.firstIndex(of: "="), equals != raw.startIndex else {
            throw BigArrowError.badInput("\(flag) needs label=value")
        }
        return (String(raw[..<equals]), String(raw[raw.index(after: equals)...]))
    }

    /// "I'm in" -> "i-m-in": a reply id from a label.
    static func slug(_ label: String) -> String {
        let parts = label.lowercased().split { !$0.isLetter && !$0.isNumber }
        return parts.isEmpty ? label : parts.joined(separator: "-")
    }
}
