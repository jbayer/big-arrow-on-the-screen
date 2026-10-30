import AppKit
import BigArrowCore

/// A borderless, non-activating, click-through panel covering one display, above everything,
/// on every Space. Recipe from Apple DTS: https://developer.apple.com/forums/thread/826308
@MainActor
final class OverlayPanel: NSPanel {
    init(screen: NSScreen, onClick: @escaping @MainActor (CGPoint) -> Void) {
        super.init(
            contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        isFloatingPanel = true
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .canJoinAllApplications, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        setFrame(screen.frame, display: false)
        let view = ClickView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.onClick = onClick
        view.wantsLayer = true
        contentView = view
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Receives the click while `ClickTracker` has made the panel clickable, with its location in the
/// panel's bottom-left points; never activates the app.
@MainActor
final class ClickView: NSView {
    var onClick: (@MainActor (CGPoint) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?(convert(event.locationInWindow, from: nil))
    }
}

/// Makes sure an unbundled executable may create windows without a Dock icon or focus change.
/// It defaults to `.prohibited`: https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy-swift.enum/prohibited
@MainActor
public enum OverlayApplication {
    public static func prepare() {
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    /// Pumps AppKit events forever without `NSApplication.run()`. That method calls
    /// `finishLaunching()`, which activates a process that has no controlling terminal (every
    /// `--detach` child) and steals the focus. Fetching events with `nextEvent` also runs the
    /// main run loop, so panels, Core Animation, timers, dispatch and signal sources all work,
    /// and the close button still receives its clicks.
    public static func runWithoutActivating() -> Never {
        let app = NSApplication.shared
        while true {
            if let event = app.nextEvent(matching: .any, until: .distantFuture, inMode: .default, dequeue: true) {
                app.sendEvent(event)
            }
        }
    }
}
