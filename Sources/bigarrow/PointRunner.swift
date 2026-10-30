import AppKit
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting
import Foundation

/// A planned arrow: the layout plus the rendered sign for one resolved target.
struct PlannedArrow {
    let resolved: ResolvedTarget
    let layout: OverlayLayout
    let sign: SignImage

    /// The result for this arrow, with every copy chip in global top-left points.
    func result(pid: Int32) -> PointResult {
        var result = PointResult(pid: pid, resolved: resolved, layout: layout)
        let sign = layout.signRect.offsetBy(dx: layout.display.frame.minX, dy: layout.display.frame.minY)
        let chips: [[Double]] = self.sign.copyButtons.map { button in
            let chip = button.rect
            return [Double(sign.minX + chip.minX), Double(sign.maxY - chip.maxY), Double(chip.width), Double(chip.height)]
        }
        result.copyButtons = chips.isEmpty ? nil : chips
        return result
    }
}

/// Resolves the target, then either prints the plan, detaches, or runs the overlay.
@MainActor
struct PointRunner {
    let config: PointConfig

    func run() throws {
        OverlayApplication.prepare()
        // A dry run or a PNG render changes nothing on screen, so it never raises an app.
        if config.raise, !config.dryRun, config.png == nil, let home = config.home {
            _ = try AppRaiser.raise(app: home.app, windowTitle: home.title, screens: ScreenReader.current())
        }
        let screens = ScreenReader.current()
        let planned = try plan(config.target.resolve(screens: screens), screens: screens)
        if let png = config.png { try render(planned, to: png) }
        if config.dryRun {
            var result = planned.result(pid: getpid())
            result.dryRun = true
            report(result)
            exit(0)
        }
        if config.detach {
            let child = try Detacher(config: config).spawn()
            var result = planned.result(pid: child.pid)
            result.detached = true
            result.moveSign(to: child.signFrame)
            result.direction = child.direction
            report(result)
            exit(0)
        }
        if let card = config.card {
            try startCard(card, with: planned)
        } else {
            try PointSession(config: config, planner: self, initial: planned).start()
        }
        OverlayApplication.runWithoutActivating()
    }

    /// `point --card`: arrow and card in one session; --duration limits the arrow, the card stays
    /// until the human clicks its X.
    func startCard(_ card: CardDocument, with planned: PlannedArrow) throws {
        let target: CardReplyTarget = config.replyFile ? .file : .stdout
        let session = try CardSession(document: card, base: planned, replyTarget: target, raise: false)
        session.arrowLimit = config.duration
        try session.start()
    }

    func render(_ planned: PlannedArrow, to png: String) throws -> Never {
        var result = planned.result(pid: getpid())
        let file = URL(fileURLWithPath: png)
        result.image = try PNGExporter.write(planned.layout, sign: planned.sign, appearance: config.appearance, to: file)
        Output.print(config.json ? JSONOutput.encode(result) : "bigarrow: wrote \(png)")
        exit(0)
    }

    func plan(_ resolved: ResolvedTarget, screens: ScreenSpace) throws -> PlannedArrow {
        let display = try screens.display(containing: resolved.shape.anchor)
        let sign = SignRenderer.render(text: config.sign, appearance: config.appearance, display: display)
        let request = OverlayLayout.Request(
            target: resolved.shape, display: display, signSize: sign.size,
            style: config.style, size: config.size, forced: config.forced, corners: config.corners, shape: config.shape,
            others: Self.otherSigns(on: display)
        )
        return PlannedArrow(resolved: resolved, layout: OverlayLayout.plan(request), sign: sign)
    }

    /// Sign frames of the other live arrows on this display, so several arrows do not overlap.
    static func otherSigns(on display: Display) -> [CGRect] {
        PidRegistry().live().filter { $0.pid != getpid() && $0.display == display.index + 1 }.compactMap { record in
            guard record.signFrame.count == 4 else { return nil }
            let frame = record.signFrame
            return display.local(CGRect(x: frame[0], y: frame[1], width: frame[2], height: frame[3]))
        }
    }

    func report(_ result: PointResult) {
        if config.json {
            Output.json(result)
            return
        }
        let target = "\(Output.number(result.target.x)),\(Output.number(result.target.y)) on display \(result.target.display)"
        if result.dryRun {
            Output.print("bigarrow: would point at \(target), sign on the \(result.direction)")
        } else if result.detached {
            Output.print("bigarrow: pointing at \(target) in the background, pid \(result.pid); 'bigarrow clear' removes it")
        } else {
            let after = result.dismissedAfter.map { Output.number(($0 * 10).rounded() / 10) } ?? "?"
            let reason = result.dismissedReason?.rawValue ?? "?"
            let copied = result.copied.map { ", value copied \($0)x" } ?? ""
            Output.print("bigarrow: pointed at \(target) for \(after) s, dismissed by \(reason)\(copied)")
        }
    }
}

extension PointResult {
    /// The detached child placed the sign itself; its copy chips move with it.
    mutating func moveSign(to frame: [Double]) {
        let (dx, dy) = (frame[0] - sign[0], frame[1] - sign[1])
        copyButtons = copyButtons?.map { [$0[0] + dx, $0[1] + dy, $0[2], $0[3]] }
        sign = frame
    }
}
