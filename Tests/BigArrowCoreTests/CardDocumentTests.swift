@testable import BigArrowCore
import CoreGraphics
import Foundation
import Testing

/// The cue card format: parsing, validation, redaction and the reply. Pure, no screen.
@Suite("Card document")
struct CardDocumentTests {
    func parse(_ json: String) throws -> CardDocument {
        try CardDocument.parse(Data(json.utf8))
    }

    func badInput(_ json: String) -> String? {
        do {
            _ = try parse(json)
            return nil
        } catch let error as BigArrowError {
            #expect(error.code == .badInput)
            return error.message
        } catch {
            return "\(error)"
        }
    }

    @Test("Every use case in docs/cards parses and validates")
    func useCases() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("docs/cards")
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        #expect(files.count == 20)
        for file in files {
            #expect(throws: Never.self, "\(file.lastPathComponent)") { try CardDocument.parse(Data(contentsOf: file)) }
        }
    }

    @Test("An unknown key anywhere is bad input that names it, so a typo never drops a row silently")
    func unknownKeys() {
        #expect(badInput(#"{"title":"t","rows":[{"type":"text","value":"x"}],"colour":"red"}"#)?.contains("'colour'") == true)
        #expect(badInput(#"{"title":"t","rows":[{"type":"text","valu":"x"}]}"#)?.contains("row 1: unknown key 'valu'") == true)
        let point = #"{"title":"t","rows":[{"type":"field","label":"a","value":"b","point":{"elment":"x"}}]}"#
        #expect(badInput(point)?.contains("row 1 point") == true)
    }

    @Test("Each row kind says what it is missing")
    func validation() {
        #expect(badInput(#"{"title":" ","rows":[{"type":"text","value":"x"}]}"#)?.contains("title") == true)
        #expect(badInput(#"{"title":"t","rows":[]}"#)?.contains("at least one row") == true)
        #expect(badInput(#"{"title":"t","rows":[{"type":"field","value":"x"}]}"#)?.contains("needs a label") == true)
        #expect(badInput(#"{"title":"t","rows":[{"type":"link","url":"example.com"}]}"#)?.contains("scheme") == true)
        #expect(badInput(#"{"title":"t","rows":[{"type":"choice","items":[{"id":"a","label":"A"}]}]}"#)?.contains("2 to 6") == true)
        #expect(badInput(#"{"title":"t","rows":[{"type":"progress","progress":1.5}]}"#)?.contains("between 0 and 1") == true)
        #expect(badInput(#"{"title":"t","rows":[{"type":"tick"}]}"#) != nil)
        let twice = #"{"title":"t","rows":[{"type":"actions","items":[{"id":"a","label":"A"},{"id":"a","label":"B"}]}]}"#
        #expect(badInput(twice)?.contains("used twice") == true)
    }

    @Test("A secret is masked and never survives redaction; a card has no time limit")
    func secrets() throws {
        let card = try parse(#"{"title":"t","rows":[{"type":"field","label":"Password","value":"hunter2","masked":true}]}"#)
        #expect(card.hasSecret)
        let redacted = JSONOutput.encode(card.redacted)
        #expect(!redacted.contains("hunter2"))
        #expect(redacted.contains(CardDocument.redaction))
        let plain = try parse(#"{"title":"t","rows":[{"type":"field","label":"User","value":"franz"}]}"#)
        #expect(badInput(#"{"title":"t","rows":[{"type":"text","value":"x"}],"duration":60}"#)?.contains("'duration'") == true)
        #expect(JSONOutput.encode(plain.redacted).contains("franz"))
    }

    @Test("A row point becomes the same options bigarrow point takes")
    func pointArguments() throws {
        var point = CardPoint(element: "Password")
        #expect(try point.targetArguments(defaultApp: "Safari") == ["--element", "Password", "--app", "Safari"])
        point.app = "Google Chrome:Login"
        point.role = "textfield"
        let expected = ["--element", "Password", "--role", "textfield", "--app", "Google Chrome:Login"]
        #expect(try point.targetArguments(defaultApp: "Safari") == expected)
        var window = CardPoint()
        window.window = "Finder"
        #expect(try window.targetArguments(defaultApp: "Safari") == ["--window", "Finder"])
        #expect(throws: BigArrowError.self) { try CardPoint().targetArguments(defaultApp: nil) }
    }

    @Test("The reply lists what happened, never a value, and exits 0 only for an answer")
    func reply() throws {
        var progress = CardProgress()
        progress.noteCopy("Password")
        progress.noteCopy("Password")
        progress.inputs = ["ip": "91.99.153.175", "empty": ""]
        let reply = progress.reply(pid: 42, result: .button, value: "done", startedAt: Date().addingTimeInterval(-3))
        #expect(reply.copied == ["Password"])
        #expect(reply.inputs == ["ip": "91.99.153.175"])
        #expect(reply.exitCode == 0)
        let parsed = try #require(CardReply.parse(Data(reply.line().utf8)))
        #expect(parsed.result == .button)
        #expect(parsed.value == "done")
        #expect(CardReply(pid: 1, result: .closed, after: 1).exitCode == 1)
        #expect(CardOutcome(.timeout) == .timeout)
        #expect(CardOutcome(.signal) == .stopped)
        #expect(CardOutcome(.clicked) == .closed)
    }

    @Test("Every Feather icon parses into its 24-unit box; curves and circles included")
    func icons() {
        for icon in FeatherIcon.allCases {
            let box = icon.path.boundingBoxOfPath
            #expect(CGRect(x: 0, y: 0, width: 24, height: 24).insetBy(dx: -0.5, dy: -0.5).contains(box), "\(icon) \(box)")
            #expect(box.width > 8, "\(icon) draws almost nothing")
        }
        let eye = FeatherIcon.eye.path.boundingBoxOfPath
        #expect(abs(eye.minX - 1) < 0.01 && abs(eye.maxX - 23) < 0.01)
    }

    @Test("Colours print as hex that parses back")
    func hexColour() throws {
        for preset in ArrowColor.presets {
            let colour = try ArrowColor.parse(preset.name)
            #expect(try ArrowColor.parse(colour.hex) == colour)
            #expect(colour.hex == "#\(preset.hex)")
        }
    }
}
