import Foundation

/// The sign's text: a sentence in which `{{value}}` marks a value the human can copy with one
/// click, e.g. "Franz, copy {{sudo xcodebuild -license accept}} and paste it here".
public struct SignText: Equatable, Sendable {
    public enum Segment: Equatable, Sendable {
        case plain(String)
        case copy(String)
    }

    public static let open = "{{"
    public static let close = "}}"

    public let segments: [Segment]

    /// The sentence without braces, values included: what `--say` speaks and the pid file records.
    public var plain: String {
        segments.map { segment in
            switch segment {
            case .plain(let text), .copy(let text): text
            }
        }.joined()
    }

    /// The values that get a copy button, in reading order.
    public var copyValues: [String] {
        segments.compactMap { segment in
            if case .copy(let value) = segment { value } else { nil }
        }
    }

    public init(segments: [Segment]) {
        self.segments = segments
    }

    /// Splits at `{{` and `}}`. Unbalanced or empty markers are bad input, never guessed.
    public static func parse(_ raw: String) throws -> SignText {
        var segments: [Segment] = []
        var rest = Substring(raw)
        while let start = rest.range(of: open) {
            try appendPlain(rest[..<start.lowerBound], to: &segments)
            let afterOpen = rest[start.upperBound...]
            guard let end = afterOpen.range(of: close) else {
                throw BigArrowError.badInput("--text has '\(open)' without '\(close)': write {{value}} for a copy button")
            }
            let value = afterOpen[..<end.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !value.contains(open) else {
                throw BigArrowError.badInput("--text has an empty or nested {{ }}: write {{value}} for a copy button")
            }
            segments.append(.copy(value))
            rest = afterOpen[end.upperBound...]
        }
        try appendPlain(rest, to: &segments)
        return SignText(segments: segments)
    }

    static func appendPlain(_ text: Substring, to segments: inout [Segment]) throws {
        guard !text.contains(close) else {
            throw BigArrowError.badInput("--text has '\(close)' without '\(open)': write {{value}} for a copy button")
        }
        if !text.isEmpty { segments.append(.plain(String(text))) }
    }
}
