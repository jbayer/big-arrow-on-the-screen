import BigArrowCore
import Darwin
import Foundation

/// Starts a bigarrow child in its own session with /dev/null for stdout and stderr, so an agent's
/// shell call returns at once and is never held open by the child's pipes. Data for the child
/// (a card with its secrets) goes through a pipe on its stdin, never through its arguments.
enum ChildProcess {
    static let readyTimeout: TimeInterval = 3
    static let pollInterval: useconds_t = 5_000

    static func spawn(_ executable: String, _ arguments: [String], stdin: Data? = nil) throws -> Int32 {
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        posix_spawn_file_actions_init(&actions)
        posix_spawnattr_init(&attributes)
        defer {
            posix_spawn_file_actions_destroy(&actions)
            posix_spawnattr_destroy(&attributes)
        }
        var pipeEnds: [Int32] = [-1, -1]
        if stdin != nil, pipe(&pipeEnds) == 0 {
            posix_spawn_file_actions_adddup2(&actions, pipeEnds[0], 0)
            posix_spawn_file_actions_addclose(&actions, pipeEnds[1])
        } else {
            posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
        }
        posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
        posix_spawn_file_actions_addopen(&actions, 2, "/dev/null", O_WRONLY, 0)
        posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))
        let pid = try run(executable, arguments, actions: &actions, attributes: &attributes)
        if let stdin, pipeEnds[1] >= 0 { feed(stdin, read: pipeEnds[0], write: pipeEnds[1]) }
        return pid
    }

    static func run(
        _ executable: String, _ arguments: [String], actions: inout posix_spawn_file_actions_t?, attributes: inout posix_spawnattr_t?
    ) throws -> Int32 {
        let argv = arguments.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var pid: pid_t = 0
        let status = posix_spawn(&pid, executable, &actions, &attributes, argv, environ)
        guard status == 0 else {
            throw BigArrowError.badInput("could not start the detached process: \(String(cString: strerror(status)))")
        }
        return pid
    }

    /// Writes the data into the child's stdin and closes it, so the child reads to the end.
    static func feed(_ data: Data, read: Int32, write: Int32) {
        close(read)
        let handle = FileHandle(fileDescriptor: write, closeOnDealloc: true)
        handle.write(data)
        try? handle.close()
    }

    /// The child writes its pid file right after its window is on screen.
    static func waitUntilShown(_ pid: Int32) throws {
        let file = PidRegistry().file(for: pid).path
        let deadline = Date().addingTimeInterval(readyTimeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: file) { return }
            var status: Int32 = 0
            if waitpid(pid, &status, WNOHANG) == pid {
                let code = (status >> 8) & 0xFF
                let exitCode = ExitCode(rawValue: code) ?? .targetUnresolvable
                throw BigArrowError(exitCode, "the detached process exited with code \(code) before showing")
            }
            usleep(pollInterval)
        }
        throw BigArrowError.unresolvable("the detached process (pid \(pid)) did not show within \(Int(readyTimeout)) s")
    }
}
