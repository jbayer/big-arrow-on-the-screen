import BigArrowCore
import Foundation

/// Reads a card from a file or stdin, validates it and reads its secrets. Every failure happens
/// here, before anything is drawn: bad JSON exits 2, a secret source that gives nothing exits 3.
enum CardInput {
    static func load(_ path: String, stdinTaken: Bool = false) throws -> CardDocument {
        try parse(read(path, stdinTaken: stdinTaken)).resolvingSecrets()
    }

    static func read(_ path: String, stdinTaken: Bool) throws -> Data {
        guard path == "-" else {
            guard let data = FileManager.default.contents(atPath: NSString(string: path).expandingTildeInPath) else {
                throw BigArrowError.badInput("cannot read the card at \(path)")
            }
            return data
        }
        guard !stdinTaken else { throw BigArrowError.badInput("stdin already holds the Peekaboo snapshot; pass the card as a file") }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard !data.isEmpty else { throw BigArrowError.badInput("no card JSON on stdin") }
        return data
    }

    static func parse(_ data: Data) throws -> CardDocument {
        let document = try CardDocument.parse(data)
        try document.checkSecretSources()
        return document
    }
}
