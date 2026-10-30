import CoreGraphics
import Foundation

/// Reads the small SVG subset icon sets like Feather use: `<path d>` with M L H V C S A Z
/// (absolute and relative), `<rect>` with rx, `<polyline>`, `<line>` and `<circle>`. Anything else throws, so an icon that
/// needs more fails at once instead of drawing wrong.
public enum SVGPath {
    public struct Unsupported: Error, Equatable, CustomStringConvertible {
        public let description: String
    }

    /// One path in SVG user units (y down), from an icon's inner SVG elements.
    public static func icon(_ elements: String) throws -> CGPath {
        let path = CGMutablePath()
        let pattern = try NSRegularExpression(pattern: #"<(\w+)\s([^>]*?)/?>"#)
        let range = NSRange(elements.startIndex..., in: elements)
        for match in pattern.matches(in: elements, range: range) {
            try add(group(1, of: match, in: elements), attributes(group(2, of: match, in: elements)), to: path)
        }
        guard !path.isEmpty else { throw Unsupported(description: "no SVG elements in '\(elements)'") }
        return path
    }

    static func add(_ name: String, _ attributes: [String: String], to path: CGMutablePath) throws {
        switch name {
        case "path":
            var data = PathData(try attribute("d", attributes))
            try data.append(to: path)
        case "rect": try addRect(attributes, to: path)
        case "polyline": try addPolyline(attributes, to: path)
        case "line":
            let numbers = try ["x1", "y1", "x2", "y2"].map { try number(attribute($0, attributes)) }
            path.move(to: CGPoint(x: numbers[0], y: numbers[1]))
            path.addLine(to: CGPoint(x: numbers[2], y: numbers[3]))
        case "circle":
            let numbers = try ["cx", "cy", "r"].map { try number(attribute($0, attributes)) }
            let (center, radius) = (CGPoint(x: numbers[0], y: numbers[1]), numbers[2])
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        default: throw Unsupported(description: "SVG element <\(name)> is not supported")
        }
    }

    static func addRect(_ attributes: [String: String], to path: CGMutablePath) throws {
        let numbers = try ["x", "y", "width", "height"].map { try number(attribute($0, attributes)) }
        let radius = try attributes["rx"].map(number) ?? 0
        let rect = CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
        path.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    }

    static func addPolyline(_ attributes: [String: String], to path: CGMutablePath) throws {
        let numbers = try PathData.numbers(attribute("points", attributes))
        guard numbers.count >= 4, numbers.count.isMultiple(of: 2) else {
            throw Unsupported(description: "polyline needs pairs of numbers")
        }
        let points = stride(from: 0, to: numbers.count, by: 2).map { CGPoint(x: numbers[$0], y: numbers[$0 + 1]) }
        path.addLines(between: points)
    }

    static func attributes(_ raw: String) throws -> [String: String] {
        let pattern = try NSRegularExpression(pattern: #"([\w-]+)="([^"]*)""#)
        var result: [String: String] = [:]
        for match in pattern.matches(in: raw, range: NSRange(raw.startIndex..., in: raw)) {
            result[group(1, of: match, in: raw)] = group(2, of: match, in: raw)
        }
        return result
    }

    static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String {
        Range(match.range(at: index), in: text).map { String(text[$0]) } ?? ""
    }

    static func attribute(_ name: String, _ attributes: [String: String]) throws -> String {
        guard let value = attributes[name] else { throw Unsupported(description: "SVG attribute '\(name)' is missing") }
        return value
    }

    static func number(_ raw: String) throws -> CGFloat {
        guard let value = Double(raw) else { throw Unsupported(description: "'\(raw)' is not a number") }
        return CGFloat(value)
    }
}
