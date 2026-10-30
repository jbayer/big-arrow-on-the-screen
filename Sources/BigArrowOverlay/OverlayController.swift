import AppKit
import BigArrowCore

/// Owns the overlay panel for one arrow: show, move (for --follow), hide, dismiss.
@MainActor
public final class OverlayController {
    private var panel: OverlayPanel?
    private var layers: OverlayLayers?
    private(set) public var layout: OverlayLayout?
    private let mode: AnimationMode
    private let appearance: SignAppearance
    private var tracker: ClickTracker?
    private var region: ClickRegion?
    private var sign: SignImage?
    private var onClick: (@MainActor () -> Void)?
    private var onCopy: (@MainActor (String) -> Void)?

    /// How long a copy chip shows the check after a click.
    static let copiedFeedback: TimeInterval = 1.5

    public init(mode: AnimationMode, appearance: SignAppearance) {
        self.mode = mode
        self.appearance = appearance
    }

    /// A click on the sign or the shaft (never near the head or on the target) runs `handler`.
    public func dismissOnClick(_ handler: @escaping @MainActor () -> Void) {
        onClick = handler
    }

    /// A click on a copy chip puts its value on the clipboard, keeps the arrow and runs `handler`.
    public func onCopy(_ handler: @escaping @MainActor (String) -> Void) {
        onCopy = handler
    }

    /// Shows the layout on its display. The panel is reused while the display stays the same.
    public func show(_ layout: OverlayLayout, sign: SignImage, animated: Bool) throws {
        guard let screen = ScreenReader.screen(for: layout.display) else {
            throw BigArrowError.unresolvable("display \(layout.display.index + 1) is no longer connected")
        }
        if panel == nil || self.layout?.display != layout.display {
            panel?.orderOut(nil)
            panel = OverlayPanel(screen: screen) { [weak self] point in self?.clicked(at: point) }
        }
        let layers = OverlayLayers(layout: layout, sign: sign, appearance: appearance)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        panel?.contentView?.layer?.sublayers = [layers.root]
        CATransaction.commit()
        if animated { Animator.enter(layers, mode: mode) }
        self.layers = layers
        self.layout = layout
        self.sign = sign
        panel?.orderFrontRegardless()
        tracker?.stop()
        let region = ClickRegion(layout: layout, flip: layers.flip, copyButtons: sign.copyButtons.map(\.rect))
        self.region = region
        if let panel, onClick != nil {
            tracker = ClickTracker(panel: panel, root: layers.root, region: region)
        }
    }

    /// A chip copies; anywhere else on the sign or the shaft ends the arrow.
    func clicked(at point: CGPoint) {
        guard let index = region?.copyButton(at: point), let button = sign?.copyButtons[index] else {
            onClick?()
            return
        }
        copy(button)
    }

    /// Puts the value on the general pasteboard (no permission needed) and shows the check.
    func copy(_ button: CopyButton) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(button.value, forType: .string)
        guard let text = layers?.signText, let plain = sign?.text else { return }
        text.contents = button.copiedText
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.copiedFeedback) {
            MainActor.assumeIsolated {
                if text.contents as AnyObject === button.copiedText { text.contents = plain }
            }
        }
        onCopy?(button.value)
    }

    /// Display-local top-left rect to AppKit screen coordinates (bottom-left of the primary display).
    static func appKitRect(_ local: CGRect, on display: Display) -> CGRect {
        let global = local.offsetBy(dx: display.frame.minX, dy: display.frame.minY)
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return ScreenSpace.flip(global, primaryHeight: primaryHeight)
    }

    /// Hides without ending, used while a followed target is gone.
    public func hide() {
        panel?.ignoresMouseEvents = true
        panel?.orderOut(nil)
    }

    public func unhide() {
        panel?.orderFrontRegardless()
    }

    /// The window-server number of the panel, for `--json` and tests.
    public var windowNumber: Int? { panel?.windowNumber }

    /// Fades out, closes the panel, then calls `completion`.
    public func dismiss(completion: @escaping @MainActor () -> Void) {
        tracker?.stop()
        guard let root = layers?.root, mode.fadeOut > 0, panel?.isVisible == true else {
            close()
            completion()
            return
        }
        Animator.fade(root, from: root.presentation()?.opacity ?? 1, to: 0, duration: mode.fadeOut)
        DispatchQueue.main.asyncAfter(deadline: .now() + mode.fadeOut) {
            MainActor.assumeIsolated {
                self.close()
                completion()
            }
        }
    }

    private func close() {
        panel?.orderOut(nil)
        panel?.close()
        panel = nil
    }
}
