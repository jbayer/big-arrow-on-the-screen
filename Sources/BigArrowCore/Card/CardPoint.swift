import Foundation

/// Where a card row's arrow points: the same targets as `bigarrow point`, written as an object.
/// `{"element": "Password", "app": "Safari"}` means `--element Password --app Safari`.
public struct CardPoint: Codable, Equatable, Sendable {
    public var element: String?
    public var role: String?
    public var rect: String?
    public var at: String?
    public var window: String?
    public var anchor: String?
    /// `App` or `App:window or tab title`; defaults to the card's `app`.
    public var app: String?
    /// The arrow's sign; defaults to "Paste <label> here" (checklist: the item itself).
    public var text: String?

    public init(element: String? = nil, app: String? = nil) {
        self.element = element
        self.app = app
    }

    static let keys: Set<String> = ["element", "role", "rect", "at", "window", "anchor", "app", "text"]

    /// The target as `bigarrow point` options. `defaultApp` is the card's app; a window target names its own.
    public func targetArguments(defaultApp: String?) throws -> [String] {
        let targets: [(String, String?)] = [("--element", element), ("--rect", rect), ("--at", at), ("--window", window)]
        let given = targets.filter { $0.1 != nil }
        guard given.count == 1, let (flag, raw) = given.first, let value = raw else {
            throw BigArrowError.badInput("a card point needs exactly one of element, rect, at or window")
        }
        var arguments = [flag, value]
        if let role { arguments += ["--role", role] }
        if let anchor { arguments += ["--anchor", anchor] }
        if window == nil, let home = app ?? defaultApp { arguments += ["--app", home] }
        return arguments
    }
}
