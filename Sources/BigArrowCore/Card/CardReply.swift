import CoreGraphics
import Foundation

/// A button or field on a card: its label and its rect (x, y, width, height).
public struct CardControl: Codable, Equatable, Sendable {
    public let name: String
    public let rect: [Double]

    public init(name: String, rect: CGRect) {
        self.name = name
        self.rect = [rect.minX, rect.minY, rect.width, rect.height].map { Double($0) }
    }
}

/// How a card ended.
public enum CardOutcome: String, Codable, Sendable {
    /// Answers: a button, an option, a typed reply, every checklist item ticked.
    case button, choice, input, checklist
    /// No answer.
    case closed, timeout, stopped, ownerGone, displayGone

    public var isAnswer: Bool { [.button, .choice, .input, .checklist].contains(self) }

    public init(_ reason: DismissReason) {
        switch reason {
        case .timeout: self = .timeout
        case .ownerGone: self = .ownerGone
        case .displayGone: self = .displayGone
        case .closed, .clicked: self = .closed
        case .signal, .targetGone: self = .stopped
        }
    }
}

/// What the human did with a card: one JSON line on stdout. Never contains a secret: `copied`
/// names the rows by label.
public struct CardReply: Codable, Equatable, Sendable {
    public var ok = true
    public let pid: Int32
    public let result: CardOutcome
    /// The button, option or typed text that answered.
    public var value: String?
    /// Every input row's text by row id, also when a button answered.
    public var inputs: [String: String]?
    /// With more than one question: every answer by row (its id, else "row N").
    public var answers: [String: String]?
    public var checked: [String]?
    public var copied: [String]?
    public var opened: [String]?
    public var after: Double
    public var at: Date

    public init(pid: Int32, result: CardOutcome, after: Double, at: Date = Date()) {
        self.pid = pid
        self.result = result
        self.after = (after * 100).rounded() / 100
        self.at = at
    }

    /// Exit 0 for an answer, 1 when the card ended without one.
    public var exitCode: Int32 { result.isAnswer ? 0 : 1 }

    public func line() -> String {
        JSONOutput.encode(self)
    }

    public static func parse(_ data: Data) -> CardReply? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CardReply.self, from: data)
    }
}

/// What a running card has collected so far, turned into the reply when it ends.
public struct CardProgress: Sendable {
    public var copied: [String] = []
    public var opened: [String] = []
    public var checked: [String] = []
    public var inputs: [String: String] = [:]
    public var answers: [String: String] = [:]

    public init() {}

    public mutating func noteCopy(_ name: String) {
        if !copied.contains(name) { copied.append(name) }
    }

    public mutating func noteOpen(_ url: String) {
        if !opened.contains(url) { opened.append(url) }
    }

    public func reply(pid: Int32, result: CardOutcome, value: String?, startedAt: Date) -> CardReply {
        var reply = CardReply(pid: pid, result: result, after: Date().timeIntervalSince(startedAt))
        reply.value = value
        reply.copied = copied.isEmpty ? nil : copied
        reply.opened = opened.isEmpty ? nil : opened
        reply.checked = checked.isEmpty ? nil : checked
        let typed = inputs.filter { !$0.value.isEmpty }
        reply.inputs = typed.isEmpty ? nil : typed
        reply.answers = answers.isEmpty ? nil : answers
        return reply
    }
}
