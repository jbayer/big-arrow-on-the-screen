import BigArrowCore
import CoreGraphics
import Testing

@Suite("Copy values in the sign")
struct SignTextTests {
    @Test("{{value}} becomes a copy segment; the plain text keeps the value without braces")
    func parses() throws {
        let text = try SignText.parse("Franz, copy {{sudo xcodebuild -license accept}} and paste it here")
        #expect(text.segments == [.plain("Franz, copy "), .copy("sudo xcodebuild -license accept"), .plain(" and paste it here")])
        #expect(text.plain == "Franz, copy sudo xcodebuild -license accept and paste it here")
        #expect(text.copyValues == ["sudo xcodebuild -license accept"])
    }

    @Test("Several values, at the start and the end, values trimmed")
    func several() throws {
        let text = try SignText.parse("{{ franz }} / {{s3cret}}")
        #expect(text.segments == [.copy("franz"), .plain(" / "), .copy("s3cret")])
        #expect(try SignText.parse("No values here").segments == [.plain("No values here")])
    }

    @Test("Unbalanced, empty or nested markers are bad input", arguments: [
        "Copy {{this", "Copy this}}", "Copy {{}}", "{{ }}", "{{a {{b}} c}}"
    ])
    func rejects(raw: String) {
        #expect(throws: BigArrowError.self) { try SignText.parse(raw) }
    }
}

@Suite("SVG icons")
struct SVGPathTests {
    @Test("Feather's copy icon spans its two squares, x and y from 2 to 22")
    func copyBounds() {
        let box = FeatherIcon.copy.path.boundingBoxOfPath
        #expect(abs(box.minX - 2) < 0.01 && abs(box.minY - 2) < 0.01)
        #expect(abs(box.maxX - 22) < 0.01 && abs(box.maxY - 22) < 0.01)
    }

    @Test("The arc corner of the back square stays inside its 2-unit radius")
    func arcCorner() throws {
        let corner = try SVGPath.icon(#"<path d="M4 2a2 2 0 0 0-2 2"></path>"#)
        let box = corner.boundingBoxOfPath
        #expect(abs(box.minX - 2) < 0.01 && abs(box.maxX - 4) < 0.01)
        #expect(abs(box.minY - 2) < 0.01 && abs(box.maxY - 4) < 0.01)
        // The quarter circle bulges towards the top-left corner (2,2), the midpoint lies on the circle around (4,4).
        let mid = CGPoint(x: 4 - 2 / 2.0.squareRoot(), y: 4 - 2 / 2.0.squareRoot())
        #expect(corner.copy(strokingWithWidth: 0.05, lineCap: .butt, lineJoin: .miter, miterLimit: 1).contains(mid))
    }

    @Test("The check is the polyline 20,6 to 9,17 to 4,12")
    func checkBounds() {
        #expect(FeatherIcon.check.path.boundingBoxOfPath == CGRect(x: 4, y: 6, width: 16, height: 11))
    }

    @Test("Implicit linetos, relative commands and packed numbers")
    func packed() throws {
        let path = try SVGPath.icon(#"<path d="m1 1 2 0-1.5.5V4h-.5z"></path>"#)
        #expect(path.boundingBoxOfPath == CGRect(x: 1, y: 1, width: 2, height: 3))
    }

    @Test("Unsupported commands and elements fail loudly", arguments: [
        #"<path d="M0 0Q1 1 2 2"></path>"#, #"<ellipse cx="1" cy="1" rx="1" ry="2"></ellipse>"#, "", #"<path d="M0 0L1"></path>"#
    ])
    func unsupported(svg: String) {
        #expect(throws: SVGPath.Unsupported.self) { try SVGPath.icon(svg) }
    }
}
