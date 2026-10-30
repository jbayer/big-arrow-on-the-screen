import AppKit
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting
import Foundation

/// Why an arrow is hidden without ending.
enum HideReason {
    case targetMissing
    case covered
}

/// One arrow on screen, from show to dismissal. The process exits when it ends.
@MainActor
final class PointSession {
    let config: PointConfig
    let planner: PointRunner
    private(set) var planned: PlannedArrow
    let overlay: OverlayController
    let registry = PidRegistry()
    let startedAt = Date()
    var speech: Process?
    var clicks: ClickWatcher?
    var follower: Follower?
    var displayWatcher: DisplayWatcher?
    var binder: HomeBinder?
    var ownerWatch: OwnerWatch?
    let owner = ArrowOwner.current
    private var hiddenBecause: Set<HideReason> = []
    var signalSources: [DispatchSourceSignal] = []
    var finished = false
    /// Clicks on copy chips, reported when the arrow ends.
    var copies = 0

    static let clickZone: CGFloat = 80
    static let signals = [SIGTERM, SIGINT, SIGHUP]

    init(config: PointConfig, planner: PointRunner, initial: PlannedArrow) {
        self.config = config
        self.planner = planner
        self.planned = initial
        self.overlay = OverlayController(mode: AnimationMode.resolve(disabled: config.noAnimation), appearance: config.appearance)
    }

    func start() throws {
        try startClickWatcher()
        overlay.dismissOnClick { [weak self] in self?.finish(.closed) }
        overlay.onCopy { [weak self] _ in self?.copies += 1 }
        try overlay.show(planned.layout, sign: planned.sign, animated: true)
        announceWhenShown()
        installSignalHandlers()
        observeScreens()
        if config.duration > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + config.duration) {
                MainActor.assumeIsolated { self.finish(.timeout) }
            }
        }
        if config.follow { follower = Follower(session: self) }
        if let home = config.home { binder = HomeBinder(session: self, app: home.app) }
        watchOwner()
        if config.say { DispatchQueue.main.async { MainActor.assumeIsolated { self.speak() } } }
    }

    /// The arrow is hidden while any reason holds, and shown again when none does.
    func setHidden(_ hidden: Bool, because reason: HideReason) {
        let wasHidden = !hiddenBecause.isEmpty
        if hidden { hiddenBecause.insert(reason) } else { hiddenBecause.remove(reason) }
        guard hiddenBecause.isEmpty == wasHidden else { return }
        if wasHidden { overlay.unhide() } else { overlay.hide() }
    }

    /// An owner that is already gone ends the arrow at once.
    func watchOwner() {
        guard let pid = owner.pid else { return }
        guard PidRegistry.isProcessAlive(pid) else {
            DispatchQueue.main.async { MainActor.assumeIsolated { self.finish(.ownerGone) } }
            return
        }
        ownerWatch = OwnerWatch(pid: pid) { [weak self] in self?.finish(.ownerGone) }
    }

    /// Replaces the arrow with a new plan, without the entrance animation.
    func move(to next: PlannedArrow) throws {
        planned = next
        try overlay.show(next.layout, sign: next.sign, animated: false)
    }

    /// The pid file is the "arrow is on screen" signal for `--detach`, so it is written after the
    /// first run-loop turn has committed the panel to the window server.
    func announceWhenShown() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                do {
                    try self.writeRecord()
                } catch {
                    Output.fail(.badInput("cannot write the pid file: \(error.localizedDescription)"), json: self.config.json)
                }
            }
        }
    }

    func writeRecord() throws {
        let display = planned.layout.display
        var record = ArrowRecord(
            pid: getpid(), text: config.text, target: planned.resolved.shape.anchor, display: display.index + 1,
            sign: (planned.layout.signRect.offsetBy(dx: display.frame.minX, dy: display.frame.minY), planned.layout.direction.rawValue),
            startedAt: startedAt
        )
        record.owner = owner.pid == nil && owner.session == nil ? nil : owner
        try registry.write(record)
    }

    /// Without the permission: exit 4, unless an explicit --duration lets the timer end it instead.
    func startClickWatcher() throws {
        guard config.click != .off else { return }
        do {
            clicks = try ClickWatcher { [weak self] location in self?.clicked(at: location) }
        } catch let error as BigArrowError where config.durationExplicit {
            Output.printError("bigarrow: \(error.message) Falling back to --duration \(Output.number(config.duration)) s.")
        }
    }

    func clicked(at location: CGPoint) {
        guard config.click == .anywhere || clickZone.contains(location) else { return }
        finish(.clicked)
    }

    /// The target rect, or a square around a point target, in global top-left points.
    var clickZone: CGRect {
        let shape = planned.resolved.shape
        if let rect = shape.rect { return rect.insetBy(dx: -8, dy: -8) }
        let half = Self.clickZone / 2
        return CGRect(x: shape.anchor.x - half, y: shape.anchor.y - half, width: Self.clickZone, height: Self.clickZone)
    }

    func speak() {
        speech = Speech.say(config.text, voice: config.voice)
    }

    func installSignalHandlers() {
        for number in Self.signals {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { MainActor.assumeIsolated { self.finish(.signal) } }
            source.resume()
            signalSources.append(source)
        }
    }

    /// Ends the arrow when its display goes away. A CoreGraphics callback, because AppKit's
    /// screen notifications need the AppKit event loop this process deliberately does not run.
    func observeScreens() {
        displayWatcher = DisplayWatcher { [weak self] in self?.displaysChanged() }
    }

    func displaysChanged() {
        if !DisplayWatcher.activeDisplayIDs().contains(planned.layout.display.id) {
            finish(.displayGone)
        }
    }

    func finish(_ reason: DismissReason) {
        guard !finished else { return }
        finished = true
        speech?.terminate()
        clicks?.stop()
        follower?.stop()
        binder?.stop()
        ownerWatch?.stop()
        overlay.dismiss {
            self.registry.remove(pid: getpid())
            var result = self.planned.result(pid: getpid())
            result.dismissedAfter = (Date().timeIntervalSince(self.startedAt) * 100).rounded() / 100
            result.dismissedReason = reason
            result.copied = self.copies > 0 ? self.copies : nil
            self.planner.report(result)
            exit(0)
        }
    }
}
