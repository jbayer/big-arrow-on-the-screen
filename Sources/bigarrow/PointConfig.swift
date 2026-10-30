import BigArrowCore
import Foundation

/// When a click ends the arrow.
enum ClickDismissal: Equatable {
    case off
    case onTarget
    case anywhere
}

/// Validated `point` input. Every check that can fail on bad input happens here, before drawing.
struct PointConfig {
    static let defaultDuration: Double = 8
    /// Arrows that wait for the human still end by themselves, in case nobody runs `stop`.
    static let humanWaitDuration: Double = 300

    let target: TargetSpec
    /// The sign with its `{{value}}` copy buttons; `text` is the same sentence without braces.
    let sign: SignText
    let text: String
    let duration: Double
    let durationExplicit: Bool
    let forced: ApproachDirection?
    let size: ArrowSize
    let style: ArrowStyle
    let color: ArrowColor
    let corners: SignCorners
    let shape: ArrowShape
    let noAnimation: Bool
    let border: ArrowBorder
    /// Optional colours of border, text, thin edge and X button; nil picks one automatically.
    let tints: [WritableKeyPath<SignAppearance, ArrowColor?>: ArrowColor]
    let say: Bool
    let voice: String?
    let follow: Bool
    let click: ClickDismissal
    let closeButton: Bool
    /// The app (and window or tab) the target is in: raised first, and the arrow hides while it is covered.
    let home: WindowQuery?
    let raise: Bool
    let mode: PointMode
    let json: Bool
    let detach: Bool
    let dryRun: Bool
    let png: String?
    /// Set when the Peekaboo JSON came from stdin, so a detached child can be given a file.
    let stdinSnapshot: Data?
    /// `--card`: a cue card shown with the arrow, its secrets already read.
    let card: CardDocument?
    let replyFile: Bool

    init(target options: TargetOptions, look: LookOptions, behaviour: BehaviourOptions, mode: PointMode) throws {
        self.mode = mode
        home = try Self.home(options)
        let (target, stdinSnapshot) = try Self.target(options, app: home?.app)
        self.target = target
        self.stdinSnapshot = stdinSnapshot
        sign = try SignText.parse(look.text.trimmingCharacters(in: .whitespacesAndNewlines))
        text = sign.plain
        guard !text.isEmpty else { throw BigArrowError.badInput("--text must not be empty, write what the human should do") }
        forced = try ApproachDirection.parse(look.from)
        size = try ArrowSize.parse(look.size)
        style = try ArrowStyle.parse(look.style)
        color = try ArrowColor.parse(look.color)
        corners = try SignCorners.parse(look.corners)
        shape = try ArrowShape.parse(look.shape)
        (noAnimation, border) = (look.noAnimation, try ArrowBorder.parse(look.border))
        tints = try Self.tints(look)
        click = try Self.click(behaviour)
        closeButton = behaviour.closeButton
        durationExplicit = behaviour.duration != nil
        card = try Self.card(behaviour, app: options.app ?? options.window, color: color, stdinTaken: stdinSnapshot != nil)
        replyFile = behaviour.replyFile
        let waitsForHuman = click != .off || closeButton || mode == .background || card != nil
        duration = behaviour.duration ?? (waitsForHuman ? Self.humanWaitDuration : Self.defaultDuration)
        guard duration >= 0, duration.isFinite else { throw BigArrowError.badInput("--duration must be 0 or more seconds") }
        (say, voice, json, dryRun) = (behaviour.say, behaviour.voice, behaviour.json, behaviour.dryRun)
        detach = behaviour.detach || mode == .background
        png = behaviour.png
        raise = home != nil && !options.noRaise
        follow = behaviour.follow
        guard !follow || target.isFollowable else { throw BigArrowError.badInput("--follow works with --window and --element only") }
    }

    var appearance: SignAppearance {
        var appearance = SignAppearance(color: color, size: size, corners: corners)
        appearance.border = border
        for (path, tint) in tints { appearance[keyPath: path] = tint }
        appearance.closeMark = closeButton ? .cross : .none
        return appearance
    }

    /// The `--card`, in the arrow's colour and beside the target's app unless it names its own.
    static func card(_ behaviour: BehaviourOptions, app: String?, color: ArrowColor, stdinTaken: Bool) throws -> CardDocument? {
        guard let path = behaviour.card else { return nil }
        guard !behaviour.follow, !behaviour.untilClick, !behaviour.untilAnyClick else {
            throw BigArrowError.badInput("--card does not combine with --follow, --until-click or --until-any-click")
        }
        var card = try CardInput.load(path, stdinTaken: stdinTaken)
        card.color = card.color ?? color.hex
        card.app = card.app ?? app
        return card
    }

    static func tints(_ look: LookOptions) throws -> [WritableKeyPath<SignAppearance, ArrowColor?>: ArrowColor] {
        let given: [(WritableKeyPath<SignAppearance, ArrowColor?>, String?)] = [
            (\.borderColor, look.borderColor), (\.textColor, look.textColor), (\.edgeColor, look.edgeColor),
            (\.closeColor, look.closeColor), (\.closeXColor, look.closeXColor)
        ]
        var tints: [WritableKeyPath<SignAppearance, ArrowColor?>: ArrowColor] = [:]
        for (path, raw) in given {
            if let raw { tints[path] = try ArrowColor.parse(raw) }
        }
        return tints
    }

    static func click(_ behaviour: BehaviourOptions) throws -> ClickDismissal {
        switch (behaviour.untilClick, behaviour.untilAnyClick) {
        case (true, true): throw BigArrowError.badInput("use --until-click or --until-any-click, not both")
        case (true, false): return .onTarget
        case (false, true): return .anywhere
        case (false, false): return .off
        }
    }

    /// `--window App[:title]` is its own home; every other target may name one with `--app`.
    static func home(_ options: TargetOptions) throws -> WindowQuery? {
        if let window = options.window {
            guard options.app == nil else { throw BigArrowError.badInput("--window already names the app, drop --app") }
            return try WindowQuery(window)
        }
        return try options.app.map(WindowQuery.init)
    }

    static func target(_ options: TargetOptions, app: String?) throws -> (TargetSpec, Data?) {
        let given = [
            options.at != nil, options.rect != nil, options.mouse, options.window != nil,
            options.element != nil, options.peekaboo != nil, options.peekabooWindow != nil
        ].filter { $0 }.count
        guard given == 1 else {
            throw BigArrowError.badInput(
                "give exactly one target: --at, --rect, --mouse, --window, --element, --peekaboo or --peekaboo-window"
            )
        }
        if options.display != nil, options.at == nil, options.rect == nil {
            throw BigArrowError.badInput("--display only applies to --at and --rect")
        }
        if let at = options.at { return (.coordinate(try NumberListParser.point(at), display: options.display), nil) }
        if let rect = options.rect { return (.rect(try NumberListParser.rect(rect), display: options.display), nil) }
        if options.mouse { return (.mouse, nil) }
        if let window = options.window {
            return (.window(try WindowQuery(window), try WindowAnchor.parse(options.anchor)), nil)
        }
        if let element = options.element {
            return (.element(try ElementQuery(text: element, role: options.role), app: app), nil)
        }
        let (data, fromStdin) = try snapshotData(options.snapshot)
        if let id = options.peekaboo { return (.peekabooElement(id: id, snapshot: data), fromStdin ? data : nil) }
        return (.peekabooWindow(index: options.peekabooWindow ?? 0, list: data), fromStdin ? data : nil)
    }

    /// A detached child reads the stdin snapshot its parent saved for it, then deletes it.
    static func removeIfHandedOver(_ path: String) {
        let url = URL(fileURLWithPath: path)
        let registry = PidRegistry().directory.standardizedFileURL.path
        guard url.deletingLastPathComponent().standardizedFileURL.path == registry,
              url.lastPathComponent.hasPrefix(Detacher.snapshotPrefix) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func snapshotData(_ path: String?) throws -> (Data, Bool) {
        guard let path, path != "-" else {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            guard !data.isEmpty else {
                throw BigArrowError.badInput("no Peekaboo JSON on stdin, pass --snapshot snap.json from 'peekaboo see --json'")
            }
            return (data, true)
        }
        guard let data = FileManager.default.contents(atPath: path) else {
            throw BigArrowError.badInput("cannot read the Peekaboo snapshot at \(path)")
        }
        removeIfHandedOver(path)
        return (data, false)
    }
}
