import Foundation
import Testing

/// Anchors `Bundle(for:)` to the test bundle, which SwiftPM places next to the built products.
private final class BundleToken {}

/// Runs the real `bigarrow` binary that SwiftPM built next to the test bundle. No mocks.
struct BigArrowProcess {
    struct Result {
        let code: Int32
        let stdout: String
        let stderr: String
        let seconds: Double

        func json() throws -> [String: Any] {
            let text = stdout.isEmpty ? stderr : stdout
            let object = try JSONSerialization.jsonObject(with: Data(text.utf8))
            return try #require(object as? [String: Any])
        }
    }

    static var executable: URL {
        get throws {
            let url = Bundle(for: BundleToken.self).bundleURL.deletingLastPathComponent().appendingPathComponent("bigarrow")
            try #require(FileManager.default.isExecutableFile(atPath: url.path), "bigarrow not built at \(url.path)")
            return url
        }
    }

    /// Runs to completion and captures both streams.
    static func run(_ arguments: [String], stdin: Data? = nil, cwd: URL? = nil) throws -> Result {
        let process = Process()
        process.executableURL = try executable
        process.currentDirectoryURL = cwd
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        let input = Pipe()
        process.standardInput = stdin == nil ? FileHandle.nullDevice : input
        let start = Date()
        try process.run()
        if let stdin {
            input.fileHandleForWriting.write(stdin)
            try input.fileHandleForWriting.close()
        }
        let stdout = out.fileHandleForReading.readDataToEndOfFile()
        let stderr = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return Result(
            code: process.terminationStatus,
            stdout: (String(bytes: stdout, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            stderr: (String(bytes: stderr, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            seconds: Date().timeIntervalSince(start)
        )
    }

    /// The repository's root, for files like docs/cards.
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// The fixtures of the unit tests, shared so both suites read the same recordings.
    static func fixture(_ name: String) -> String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("BigArrowCoreTests/Fixtures/\(name)").path
    }
}
