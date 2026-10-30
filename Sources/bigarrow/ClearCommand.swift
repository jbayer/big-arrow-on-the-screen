import ArgumentParser
import BigArrowCore
import Foundation

struct ClearCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clear",
        abstract: "Remove the newest live arrow (--all: every arrow, --pid: one, --session: one agent session's). Alias: stop.",
        discussion: """
        Run it once the human has acted. Arrows fade out and their processes exit 0.
        --hook reads a Claude Code hook payload on stdin and silently clears that session's arrows;
        as a UserPromptSubmit hook, every arrow of a session goes away when the human answers.
        Cue cards stay until the human clicks their X; only --pid <card pid> or --cards (this
        session's cards, or every card outside a session) close one.
        """,
        aliases: ["stop"]
    )

    @Flag(help: "Remove every live arrow.")
    var all = false

    @Option(help: ArgumentHelp("Remove the arrow with this pid.", valueName: "pid"))
    var pid: Int32?

    @Option(help: ArgumentHelp("Remove every arrow drawn from this agent session.", valueName: "id"))
    var session: String?

    @Flag(help: "Read {\"session_id\"} from stdin (a Claude Code hook), clear that session's arrows, print nothing.")
    var hook = false

    @Flag(help: "Close this agent session's cue cards (every card when not run from an agent session).")
    var cards = false

    @Flag(help: "Print a JSON result.")
    var json = false

    struct Result: Codable {
        var ok = true
        let cleared: [Int32]
    }

    static let waitLimit: TimeInterval = 1
    static let pollInterval: useconds_t = 5_000

    func run() throws {
        if hook {
            clear(Self.hookSession().map { session in Self.arrows().filter { $0.owner?.session == session } } ?? [])
            return
        }
        let pids = clear(try choose(from: PidRegistry().live()))
        if pids.isEmpty, cards {
            Output.print(json ? JSONOutput.encode(Result(cleared: [])) : "bigarrow: no live cards")
            return
        }
        if json {
            Output.json(Result(cleared: pids))
        } else {
            Output.print(pids.isEmpty ? "bigarrow: no live arrows" : "bigarrow: cleared \(pids.map(String.init).joined(separator: ", "))")
        }
    }

    @discardableResult
    func clear(_ chosen: [ArrowRecord]) -> [Int32] {
        chosen.forEach { kill($0.pid, SIGTERM) }
        waitUntilGone(chosen.map(\.pid))
        return chosen.map(\.pid)
    }

    /// The `session_id` of a hook payload on stdin; nil when there is none.
    static func hookSession() -> String? {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (payload?["session_id"] as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    /// Live arrows without the cue cards, which only the X, --pid or --cards close.
    static func arrows() -> [ArrowRecord] {
        PidRegistry().live().filter { $0.kind != "card" }
    }

    func choose(from records: [ArrowRecord]) throws -> [ArrowRecord] {
        if cards {
            let mine = ArrowOwner.current.session
            return records.filter { $0.kind == "card" && (mine == nil || $0.owner?.session == mine) }
        }
        let live = records.filter { $0.kind != "card" }
        if let session { return live.filter { $0.owner?.session == session } }
        if let pid {
            guard let record = records.first(where: { $0.pid == pid }) else {
                throw BigArrowError.unresolvable("no live arrow or card with pid \(pid)")
            }
            return [record]
        }
        if all { return live }
        return live.last.map { [$0] } ?? []
    }

    /// Returns once every process has exited, at most after `waitLimit`.
    func waitUntilGone(_ pids: [Int32]) {
        let deadline = Date().addingTimeInterval(Self.waitLimit)
        while Date() < deadline, pids.contains(where: PidRegistry.isAlive) {
            usleep(Self.pollInterval)
        }
    }
}
