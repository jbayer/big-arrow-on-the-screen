import AppKit
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting
import Foundation

/// Where a card's reply goes when it ends.
enum CardReplyTarget {
    /// `card --wait` and `point --card`: printed on stdout.
    case stdout
    /// A detached card: written to the registry for `bigarrow wait`.
    case file
}

/// One card on screen, with its arrow, from show to the human's answer. The process exits when it ends.
@MainActor
final class CardSession {
    var document: CardDocument
    let color: ArrowColor
    let arrows: CardArrows
    let replyTarget: CardReplyTarget
    var controller: CardController?
    var progress = CardProgress()
    let startedAt = Date()
    let owner = ArrowOwner.current
    var ownerWatch: OwnerWatch?
    var signalSources: [DispatchSourceSignal] = []
    var finished = false
    var speech: Process?
    /// The last answer, and which question rows are answered.
    var answer: (CardOutcome, String?)?
    var answeredRows: [Int: CardOutcome] = [:]
    var replied = false
    /// `point --card --duration`: seconds until the arrow goes; the card stays.
    var arrowLimit: Double?
    /// The process's one card session. Its handlers hold it weakly, so this keeps it alive until it exits.
    static var current: CardSession?

    init(document: CardDocument, base: PlannedArrow?, replyTarget: CardReplyTarget, raise: Bool) throws {
        self.document = document
        let colorName = document.color ?? "red"
        color = try ArrowColor.parse(colorName)
        arrows = try CardArrows(document: document, color: colorName, raise: raise)
        arrows.base = base
        self.replyTarget = replyTarget
    }

    /// Shows arrow and card. The first arrow (the base arrow, else the first row that points
    /// somewhere) must resolve, so a wrong target fails with exit 3 before anything is shown.
    func start() throws {
        Self.current = self
        let first = try firstArrow()
        if let first { try arrows.show(first.planned) }
        let display = try placementDisplay()
        let view = try makeView(display: display)
        let controller = CardController(view: view)
        var placement = CardPlacement(size: controller.size, display: display)
        placement.window = try homeWindow()
        placement.avoid = arrows.keepClear
        controller.show(at: placement.origin(), theme: document.theme)
        view.markActive(first?.name)
        self.controller = controller
        announceWhenShown()
        installLifetime()
    }

    func firstArrow() throws -> (planned: PlannedArrow, name: String?)? {
        if let base = arrows.base { return (base, nil) }
        guard let (point, name) = Self.firstPoint(in: document) else { return nil }
        return (try arrows.plan(point, name: name), name)
    }

    static func firstPoint(in document: CardDocument) -> (CardPoint, String)? {
        for row in document.rows {
            if let point = row.point { return (point, row.name) }
            if let item = row.items?.first(where: { $0.point != nil }), let point = item.point { return (point, item.label) }
        }
        return nil
    }

    func makeView(display: Display) throws -> CardView {
        let maxHeight = display.visibleFrame.height * 0.8
        return try CardView(document: document, color: color, events: makeEvents(), maxHeight: maxHeight)
    }

    /// The display of the shown arrow, else of the card's app window, else of the mouse.
    func placementDisplay() throws -> Display {
        let screens = ScreenReader.current()
        if let shown = arrows.shown { return shown.layout.display }
        if let window = try homeWindow() { return try screens.display(containing: CGPoint(x: window.midX, y: window.midY)) }
        return try screens.display(containing: ScreenReader.mouseLocation())
    }

    /// The front window of the card's `app`, if it names one.
    func homeWindow() throws -> CGRect? {
        guard let app = document.app else { return nil }
        return try WindowTarget.frame(try WindowQuery(app), screens: ScreenReader.current())
    }

    func makeEvents() -> CardEvents {
        let events = CardEvents()
        events.copy = { [weak self] row, value in self?.copied(row, value: value) }
        events.open = { [weak self] url in self?.open(url) }
        events.answer = { [weak self] row, outcome, value in self?.answered(row, outcome: outcome, value: value) }
        events.close = { [weak self] in self?.finish(.closed, value: nil) }
        events.activate = { [weak self] point, name in self?.activate(point, name: name) }
        events.checked = { [weak self] ids in self?.progress.checked = ids }
        events.typed = { [weak self] id, text in self?.progress.inputs[id] = text }
        return events
    }

    func copied(_ row: CardRow, value: String) {
        let secret = row.isMasked || row.type == .totp
        let changeCount = CardClipboard.copy(value, secret: secret)
        progress.noteCopy(row.name)
        if secret { ClipboardGuard.start(changeCount: changeCount) }
    }

    func open(_ url: String) {
        guard let link = URL(string: url) else { return }
        NSWorkspace.shared.open(link)
        progress.noteOpen(url)
    }

    func activate(_ point: CardPoint, name: String) {
        if arrows.activate(point, name: name) { controller?.view.markActive(name) }
    }
}
