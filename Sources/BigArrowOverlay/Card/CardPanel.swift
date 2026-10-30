import AppKit
import BigArrowCore

/// Builds the view for one row.
@MainActor
enum RowFactory {
    static func view(for row: CardRow, style: CardStyle, events: CardEvents) throws -> NSView {
        switch row.type {
        case .field, .code, .link, .totp: try ValueRowView(row: row, style: style, events: events)
        case .text: InfoRows.text(row)
        case .progress: InfoRows.progress(row, style: style)
        case .qr: try InfoRows.qr(row)
        case .image: try InfoRows.image(row)
        case .file: try FileRowView(row: row, style: style, events: events)
        case .actions: AnswerRows.actions(row, style: style, events: events)
        case .choice: AnswerRows.choice(row, style: style, events: events)
        case .input: InputRowView(row: row, style: style, events: events)
        case .checklist: ChecklistRowView(row: row, style: style, events: events)
        }
    }
}

/// The card's window: floating above normal windows (below the arrow overlay), on every Space and
/// over full-screen apps, movable by its background. Non-activating: showing it or clicking its
/// buttons never activates bigarrow, so the human's app keeps the focus. It becomes key only when
/// the human clicks into an input row. A card with a secret asks the window server to keep it out
/// of screenshots and screen recordings.
@MainActor
final class CardPanel: NSPanel {
    let acceptsTyping: Bool
    var onEscape: () -> Void = {}

    init(view: CardView, origin: CGPoint, acceptsTyping: Bool) {
        let hidden = view.document.hasSecret
        self.acceptsTyping = acceptsTyping
        let size = view.fittingSize
        super.init(
            contentRect: CGRect(origin: origin, size: size), styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow
        sharingType = hidden ? .none : .readOnly
        contentView = view
        setFrameOrigin(origin)
    }

    override var canBecomeKey: Bool { acceptsTyping }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }
}

/// Shows a card at a place in global top-left points and closes it.
@MainActor
public final class CardController {
    public let view: CardView
    private var panel: CardPanel?

    public init(view: CardView) {
        self.view = view
    }

    /// The card's size in points, after layout.
    public var size: CGSize { view.fittingSize }

    public func show(at topLeft: CGPoint, theme: String?) {
        view.appearance = Self.appearance(theme)
        let typing = view.document.rows.contains { $0.type == .input }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let frame = ScreenSpace.flip(CGRect(origin: topLeft, size: size), primaryHeight: primaryHeight)
        let panel = CardPanel(view: view, origin: frame.origin, acceptsTyping: typing)
        panel.onEscape = { [events = view.events] in events.close() }
        panel.orderFrontRegardless()
        self.panel = panel
        CardMotion.enter(view)
    }

    /// The panel's frame in global top-left points (the human may have moved it).
    public var frame: CGRect? {
        guard let panel else { return nil }
        return ScreenSpace.flip(panel.frame, primaryHeight: NSScreen.screens.first?.frame.height ?? 0)
    }

    public var windowNumber: Int? { panel?.windowNumber }

    public func markRowAnswered(_ index: Int, chosen: String?) {
        view.markRowAnswered(index, chosen: chosen)
    }

    /// Shows the "Sent" banner and grows the panel downwards, its top edge where it was.
    public func showSent(_ text: String) {
        view.showSent(text)
        guard let panel else { return }
        view.layoutSubtreeIfNeeded()
        let size = view.fittingSize
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        // At the bottom of the screen it grows upwards instead, never under the Dock.
        if let visible = panel.screen?.visibleFrame, frame.minY < visible.minY + CardPlacement.margin {
            frame.origin.y = visible.minY + CardPlacement.margin
        }
        panel.setFrame(frame, display: true)
    }

    public func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }

    /// Fades the card out, then closes it.
    public func close(completion: @escaping @MainActor () -> Void) {
        guard panel != nil else { return completion() }
        CardMotion.leave(view) { [weak self] in
            self?.close()
            completion()
        }
    }

    static func appearance(_ theme: String?) -> NSAppearance? {
        switch theme {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }
}
