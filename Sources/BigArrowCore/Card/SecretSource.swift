import Foundation

/// Where a secret comes from. Secrets never travel on the command line, where `ps` shows them to
/// every user of the Mac; the card reads them itself from one of these sources.
public enum SecretSource: Equatable, Sendable {
    /// `pass:<path>`: the first line of `pass show <path>`.
    case pass(String)
    /// `keychain:<service>/<account>`: a generic password from the login keychain.
    case keychain(service: String, account: String)
    /// `op:<op://vault/item/field>`: the 1Password CLI.
    case onePassword(String)
    /// `env:<NAME>`: an environment variable of the agent.
    case environment(String)
    /// `file:<path>`: a file's contents, `~` expanded.
    case file(String)

    public static let schemes = ["pass", "keychain", "op", "env", "file"]

    public static var help: String {
        "secrets never go on the command line (ps shows them to everyone): name a source, "
            + schemes.map { "\($0):" }.joined(separator: ", ") + ", or put the value in the JSON card on stdin"
    }

    public static func parse(_ raw: String) throws -> SecretSource {
        let parts = raw.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2, !parts[1].isEmpty, schemes.contains(parts[0]) else {
            // Never echo the text: it may be the secret itself, written where a source belongs.
            throw BigArrowError.badInput("that is not a secret source; \(help)")
        }
        let rest = parts[1]
        switch parts[0] {
        case "pass": return .pass(rest)
        case "keychain": return try keychain(rest)
        case "op": return .onePassword(rest.hasPrefix("op://") ? rest : "op://\(rest)")
        case "env": return .environment(rest)
        default: return .file(rest)
        }
    }

    static func keychain(_ rest: String) throws -> SecretSource {
        guard let slash = rest.lastIndex(of: "/"), slash != rest.startIndex, rest.index(after: slash) != rest.endIndex else {
            throw BigArrowError.badInput("keychain source needs keychain:<service>/<account>")
        }
        return .keychain(service: String(rest[..<slash]), account: String(rest[rest.index(after: slash)...]))
    }

    /// Reads the secret; exit 3 with the source named (never the value) when it cannot.
    public func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> String {
        let value: String?
        switch self {
        case .pass(let path): value = try Self.run("pass", ["show", path], source: "pass:\(path)").firstLine
        case .keychain(let service, let account):
            value = try Self.run("security", ["find-generic-password", "-s", service, "-a", account, "-w"], source: "keychain:\(service)")
        case .onePassword(let reference): value = try Self.run("op", ["read", reference], source: reference)
        case .environment(let name): value = environment[name]
        case .file(let path): value = try? String(contentsOfFile: NSString(string: path).expandingTildeInPath, encoding: .utf8)
        }
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { throw BigArrowError.unresolvable("secret source \(description) gave no value") }
        return trimmed
    }

    public var description: String {
        switch self {
        case .pass(let path): "pass:\(path)"
        case .keychain(let service, let account): "keychain:\(service)/\(account)"
        case .onePassword(let reference): reference
        case .environment(let name): "env:\(name)"
        case .file(let path): "file:\(path)"
        }
    }

    /// Runs a tool from PATH (Homebrew's too) and returns its stdout; its stderr goes into the error.
    static func run(_ tool: String, _ arguments: [String], source: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [tool] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = (environment["PATH"].map { $0 + ":" } ?? "") + "/opt/homebrew/bin:/usr/local/bin"
        process.environment = environment
        let (out, err) = (Pipe(), Pipe())
        process.standardOutput = out
        process.standardError = err
        process.standardInput = FileHandle.nullDevice
        try process.run()
        let data = out.fileHandleForReading.readDataToEndOfFile()
        let message = String(bytes: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let reason = message.trimmingCharacters(in: .whitespacesAndNewlines).firstLine
            let detail = reason.isEmpty ? "\(tool) exited \(process.terminationStatus)" : reason
            throw BigArrowError.unresolvable("secret source \(source) failed: \(detail)")
        }
        return String(bytes: data, encoding: .utf8) ?? ""
    }
}

extension String {
    var firstLine: String {
        split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
    }
}

extension CardDocument {
    /// Every `secret` source read into `value`, the row marked masked (TOTP seeds stay unmasked codes).
    public func resolvingSecrets(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> CardDocument {
        var copy = self
        copy.rows = try rows.map { row in
            guard let source = row.secret else { return row }
            var row = row
            row.value = try SecretSource.parse(source).resolve(environment: environment)
            row.secret = nil
            if row.type != .totp { row.masked = true }
            return row
        }
        return copy
    }

    /// Fails early on a malformed source, before anything is read.
    public func checkSecretSources() throws {
        for row in rows { if let source = row.secret { _ = try SecretSource.parse(source) } }
    }
}
