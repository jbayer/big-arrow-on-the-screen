import BigArrowCore
import Darwin
import Foundation

/// `--detach`: re-runs the same command without `--detach` in a new session with /dev/null
/// for stdin, stdout and stderr, so an agent's shell call returns at once and is never held
/// open by the child's pipes. Returns once the child shows its arrow.
struct Detacher {
    let config: PointConfig
    static let snapshotPrefix = "snapshot-"
    /// Options the child gets with a new value.
    static let replaced = ["--duration", "--card"]

    /// Starts the child and returns its own record of what it drew, which is the truth even if
    /// the screen changed (Dock shown, display added) between the parent's plan and the child's.
    func spawn() throws -> ArrowRecord {
        guard let executable = Bundle.main.executablePath else {
            throw BigArrowError.badInput("cannot find the bigarrow executable to detach")
        }
        let arguments = try childArguments(executable: executable)
        let pid = try ChildProcess.spawn(executable, arguments, stdin: config.card?.encoded())
        try ChildProcess.waitUntilShown(pid)
        guard let record = PidRegistry().read(pid: pid) else {
            throw BigArrowError.unresolvable("the detached arrow (pid \(pid)) wrote no readable pid file")
        }
        return record
    }

    func childArguments(executable: String) throws -> [String] {
        var arguments = [executable, "point"] + Self.optionsWithoutDuration(CommandLine.arguments.dropFirst(2))
        arguments += ["--duration", String(config.duration)]
        // The card, its secrets read already, reaches the child through a pipe on its stdin.
        if config.card != nil { arguments += ["--card", "-", "--reply-file"] }
        // The parent already raised the target's app; raising twice only costs time.
        if !arguments.contains("--no-raise") { arguments.append("--no-raise") }
        if let data = config.stdinSnapshot {
            let file = PidRegistry().directory.appendingPathComponent("\(Self.snapshotPrefix)\(UUID().uuidString).json")
            try FileManager.default.createDirectory(at: PidRegistry().directory, withIntermediateDirectories: true)
            try data.write(to: file)
            arguments += ["--snapshot", file.path]
        }
        return arguments
    }

    /// The child is always a foreground `point`; `--detach` is dropped and the resolved duration
    /// is passed explicitly, because `start` and `point` default to different durations.
    /// `--card` is dropped too: the child reads the resolved card from its stdin.
    static func optionsWithoutDuration(_ arguments: ArraySlice<String>) -> [String] {
        var result: [String] = []
        var skipNext = false
        for argument in arguments {
            if skipNext {
                skipNext = false
            } else if replaced.contains(argument) {
                skipNext = true
            } else if argument != "--detach", !replaced.contains(where: { argument.hasPrefix($0 + "=") }) {
                result.append(argument)
            }
        }
        return result
    }
}
