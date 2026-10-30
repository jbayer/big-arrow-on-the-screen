import ArgumentParser
import BigArrowCore
import Darwin
import Foundation

struct WaitCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait",
        abstract: "Wait for the human to answer a card, then print the reply JSON (exit 0 answered, 1 not).",
        discussion: """
        Without a pid: the newest live card of this agent session. Returns as soon as the human
        answers (the card stays up until its X) or closes the card. --timeout returns sooner
        with {"result":"pending"} and leaves the card up.
        """
    )

    @Argument(help: "The card's pid, as 'bigarrow card' printed it.")
    var pid: Int32?

    @Option(help: help("Give up after this many seconds and print a pending result (0 = until the card ends).", "seconds"))
    var timeout: Double = 0

    @Flag(help: "Errors as JSON on stderr (results are always JSON).")
    var json = false

    static let pollInterval: TimeInterval = 0.1

    struct Pending: Codable {
        var ok = true
        let pid: Int32
        var result = "pending"
    }

    func run() throws {
        try Self.reply(of: try pid ?? Self.newestCard(), timeout: timeout)
    }

    /// Prints the card's reply as soon as there is one and exits with its code.
    static func reply(of pid: Int32, timeout: Double) throws -> Never {
        let registry = PidRegistry()
        let deadline = timeout > 0 ? Date().addingTimeInterval(timeout) : Date.distantFuture
        while true {
            if let data = try? Data(contentsOf: registry.replyFile(for: pid)), let reply = CardReply.parse(data) {
                try? FileManager.default.removeItem(at: registry.replyFile(for: pid))
                Output.print(reply.line())
                Darwin.exit(reply.exitCode)
            }
            if !PidRegistry.isAlive(pid), !FileManager.default.fileExists(atPath: registry.replyFile(for: pid).path) {
                throw BigArrowError.unresolvable("no card with pid \(pid) is running or left a reply")
            }
            if Date() >= deadline {
                Output.json(Pending(pid: pid))
                Darwin.exit(1)
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }

    /// This session's newest card, else the newest card at all.
    static func newestCard() throws -> Int32 {
        let cards = PidRegistry().live().filter { $0.kind == "card" }
        let session = ArrowOwner.current.session
        let mine = cards.filter { session != nil && $0.owner?.session == session }
        guard let card = (mine.isEmpty ? cards : mine).last else {
            throw BigArrowError.unresolvable("no live card; pass the pid 'bigarrow card' printed")
        }
        return card.pid
    }
}
