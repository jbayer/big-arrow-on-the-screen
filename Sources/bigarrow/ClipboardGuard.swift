import AppKit
import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import Foundation

/// Empties the clipboard 30 s after a secret was copied from a card, unless something else was
/// copied since. A detached helper, so it also happens when the card has already ended.
enum ClipboardGuard {
    static func start(changeCount: Int) {
        guard let executable = Bundle.main.executablePath else { return }
        let arguments = [executable, "clipboard-guard", "--change-count", String(changeCount)]
        _ = try? ChildProcess.spawn(executable, arguments)
    }
}

struct ClipboardGuardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "clipboard-guard",
        abstract: "Clear a secret copied from a card after 30 s (started by the card itself).",
        shouldDisplay: false
    )

    @Option(name: .customLong("change-count"), help: "The clipboard's change count right after the copy.")
    var changeCount: Int

    @Option(help: "Seconds to wait.")
    var after: Double = 30

    func run() throws {
        Thread.sleep(forTimeInterval: after)
        MainActor.assumeIsolated { _ = CardClipboard.clear(ifUnchangedSince: changeCount) }
    }
}
