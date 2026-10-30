import AppKit
import Foundation
import Testing

/// `bigarrow card` and `wait` through the real binary, drawing nothing: --dry-run, --png and errors.
@Suite("Card CLI")
struct CardCLITests {
    @Test("Flags build the card; --dry-run prints it with secrets hidden")
    func flags() throws {
        let result = try BigArrowProcess.run([
            "card", "--title", "Franz, log in", "--field", "User=franz", "--secret", "Password=env:BIGARROW_TEST_SECRET",
            "--link", "Console=https://example.com/?a=b", "--choice", "a=One", "--choice", "Two", "--button", "I'm in", "--dry-run"
        ])
        #expect(result.code == 0, "\(result.stderr)")
        let rows = try #require(result.json()["rows"] as? [[String: Any]])
        #expect(rows.map { $0["type"] as? String } == ["field", "field", "link", "choice", "actions"])
        #expect(rows[1]["secret"] as? String == "env:BIGARROW_TEST_SECRET")
        #expect(rows[2]["label"] as? String == "Console" && rows[2]["url"] as? String == "https://example.com/?a=b")
        let items = try #require(rows[3]["items"] as? [[String: Any]])
        #expect(items.map { $0["id"] as? String } == ["a", "two"])
        #expect((rows[4]["items"] as? [[String: Any]])?.first?["id"] as? String == "i-m-in")
    }

    @Test("A secret written on the command line is refused without echoing it")
    func literalSecret() throws {
        let result = try BigArrowProcess.run(["card", "--title", "t", "--secret", "Password=hunter2", "--dry-run"])
        #expect(result.code == 2)
        #expect(result.stderr.contains("ps shows them"))
        #expect(!result.stderr.contains("hunter2"))
    }

    @Test("A secret source that gives nothing exits 3 and names the source, never a value")
    func emptySource() throws {
        let result = try BigArrowProcess.run(["card", "--title", "t", "--secret", "P=env:BIGARROW_SURELY_UNSET", "--png", "/dev/null"])
        #expect(result.code == 3)
        #expect(result.stderr.contains("env:BIGARROW_SURELY_UNSET"))
    }

    @Test("A JSON card on stdin with an unknown key is bad input")
    func unknownKey() throws {
        let json = Data(#"{"title":"t","rows":[{"type":"text","value":"x","colour":"red"}]}"#.utf8)
        let result = try BigArrowProcess.run(["card", "-", "--dry-run"], stdin: json)
        #expect(result.code == 2)
        #expect(result.stderr.contains("unknown key 'colour'"))
    }

    @Test("--png renders every use case offscreen at 2x the card's width")
    func png() throws {
        let folder = BigArrowProcess.root.appendingPathComponent("docs/cards")
        let out = FileManager.default.temporaryDirectory.appendingPathComponent("bigarrow-card-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: out) }
        for name in ["01-login", "09-choice", "13-progress"] {
            let card = folder.appendingPathComponent("\(name).json").path
            let result = try BigArrowProcess.run(["card", card, "--png", out.path], cwd: BigArrowProcess.root)
            #expect(result.code == 0, "\(name): \(result.stderr)")
            let size = try #require(result.json()["size"] as? [Double])
            #expect(size[0] == 440)
            let image = try #require(NSImageRep(contentsOf: out))
            #expect(image.pixelsWide == 880)
        }
    }

    @Test("wait for a card that does not exist exits 3")
    func waitMissing() throws {
        let result = try BigArrowProcess.run(["wait", "999999"])
        #expect(result.code == 3)
    }

    @Test("point --card with --follow is bad input")
    func cardWithFollow() throws {
        let json = Data(#"{"title":"t","rows":[{"type":"text","value":"x"}]}"#.utf8)
        let arguments = ["point", "--window", "Finder", "--text", "x", "--card", "-", "--follow", "--dry-run"]
        let result = try BigArrowProcess.run(arguments, stdin: json)
        #expect(result.code == 2)
        #expect(result.stderr.contains("--card does not combine"))
    }
}
