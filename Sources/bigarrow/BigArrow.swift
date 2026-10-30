import ArgumentParser
import BigArrowCore
import Foundation

@main
struct BigArrow: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "bigarrow",
        abstract: "Point at something on the screen with a big arrow and a sign. Click-through, gone by itself.",
        discussion: """
        Coordinates are global top-left logical points (what Accessibility, CGWindowList and \
        Peekaboo report). Exit codes: 0 ok, 1 card ended without an answer, 2 bad input, 3 target \
        unresolvable, 4 permission missing.
        """,
        version: "bigarrow \(BigArrowVersion.current)",
        subcommands: [
            PointCommand.self, StartCommand.self, CardCommand.self, WaitCommand.self, ClearCommand.self, FrontCommand.self,
            ElementsCommand.self, DoctorCommand.self, DemoCommand.self, InstallSkillCommand.self, ClipboardGuardCommand.self
        ]
    )

    /// Maps every failure onto the documented exit codes; argument errors are bad input (2).
    static func main() {
        let wantsJSON = CommandLine.arguments.contains("--json")
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch let error as BigArrowError {
            Output.fail(error, json: wantsJSON)
        } catch {
            if exitCode(for: error) == .success { exit(withError: error) }
            Output.fail(.badInput(fullMessage(for: error)), json: wantsJSON)
        }
    }
}
