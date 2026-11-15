import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import Foundation

/// What `confetti` reports.
struct ConfettiResult: Encodable {
    var ok = true
    var pid: Int32
    let displays: [Int]
    let duration: Double
    let pieces: Int
    var dryRun = false
    var detached = false
}

struct ConfettiCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "confetti",
        abstract: "Confetti over the whole screen from every side, click-through, gone by itself (default 5 s).",
        discussion: """
        Celebrate a finished step: cannons in the corners, on the sides and along the bottom, and a
        rain from the top, over every display (or one with --display). Always plays, Reduce Motion or not;
        it never takes the focus and lets every click through.

          bigarrow confetti
          bigarrow confetti --duration 8 --detach
          bigarrow point --element "Merge" --app "Google Chrome" --text "Franz, it's green: merge it" --confetti
        """
    )

    @Option(help: help("Seconds of confetti, at most 30.", "seconds"))
    var duration: Double = ConfettiPlan.defaultDuration

    @Option(help: help("Only display N (1-based, see 'bigarrow doctor'); default: every display.", "n"))
    var display: Int?

    @Flag(help: "Return at once and leave the confetti falling in the background; prints the pid.")
    var detach = false

    @Flag(name: .customLong("dry-run"), help: "Plan the confetti, draw nothing.")
    var dryRun = false

    @Flag(help: "Print a JSON result to stdout (errors as JSON on stderr).")
    var json = false

    func run() throws {
        try MainActor.assumeIsolated { try runOnMain() }
    }

    @MainActor
    func runOnMain() throws {
        OverlayApplication.prepare()
        let displays = try Self.displays(display, in: ScreenReader.current())
        let plans = try displays.map { try ConfettiPlan(display: $0.frame.size, duration: duration) }
        var result = ConfettiResult(
            pid: getpid(), displays: displays.map { $0.index + 1 }, duration: duration, pieces: plans.map(\.totalPieces).reduce(0, +)
        )
        if dryRun {
            result.dryRun = true
            return report(result)
        }
        if detach {
            result.pid = try spawnChild()
            result.detached = true
            return report(result)
        }
        try ConfettiShow().start(on: displays, duration: duration) {
            report(result)
            Darwin.exit(0)
        }
        OverlayApplication.runWithoutActivating()
    }

    /// The same command without `--detach`, in its own session.
    func spawnChild() throws -> Int32 {
        guard let executable = Bundle.main.executablePath else {
            throw BigArrowError.badInput("cannot find the bigarrow executable to detach")
        }
        let arguments = CommandLine.arguments.dropFirst().filter { $0 != "--detach" && $0 != "--json" }
        return try ChildProcess.spawn(executable, [executable] + arguments)
    }

    static func displays(_ number: Int?, in screens: ScreenSpace) throws -> [Display] {
        guard let number else { return screens.displays }
        guard screens.displays.indices.contains(number - 1) else {
            throw BigArrowError.badInput("--display \(number) does not exist, there are \(screens.displays.count) displays")
        }
        return [screens.displays[number - 1]]
    }

    func report(_ result: ConfettiResult) {
        if json { return Output.json(result) }
        let place = result.displays.count == 1 ? "display \(result.displays[0])" : "\(result.displays.count) displays"
        let seconds = Output.number(result.duration)
        if result.dryRun {
            Output.print("bigarrow: would fire about \(result.pieces) pieces of confetti on \(place) for \(seconds) s")
        } else if result.detached {
            Output.print("bigarrow: confetti on \(place) for \(seconds) s in the background, pid \(result.pid)")
        } else {
            Output.print("bigarrow: fired confetti on \(place) for \(seconds) s")
        }
    }
}
