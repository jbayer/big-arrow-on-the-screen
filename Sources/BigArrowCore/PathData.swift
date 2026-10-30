import CoreGraphics
import Foundation

/// An SVG `d` attribute with M L H V C S A Z, absolute and relative, repeated parameters allowed.
/// Arcs follow the endpoint-to-centre conversion of SVG 1.1, appendix F.6.5:
/// https://www.w3.org/TR/SVG11/implnote.html#ArcConversionEndpointToCenter
struct PathData {
    private var scanner: PathScanner
    private var current = CGPoint.zero
    private var start = CGPoint.zero
    /// The second control point of the last cubic curve, which `S` mirrors.
    private var control: CGPoint?

    init(_ data: String) {
        scanner = PathScanner(data)
    }

    /// The numbers of a `points` list, e.g. a polyline's.
    static func numbers(_ list: String) throws -> [CGFloat] {
        var scanner = PathScanner(list)
        var result: [CGFloat] = []
        while scanner.hasNumber { result.append(try scanner.number()) }
        guard scanner.atEnd else { throw SVGPath.Unsupported(description: "unexpected points at '\(scanner.rest)'") }
        return result
    }

    mutating func append(to path: CGMutablePath) throws {
        while let command = scanner.command() {
            let relative = command.lowercased() == command
            var name = command.uppercased()
            repeat {
                try step(name, relative: relative, path: path)
                // Pairs after a moveto are implicit linetos.
                if name == "M" { name = "L" }
            } while name != "Z" && scanner.hasNumber
        }
        guard scanner.atEnd else { throw SVGPath.Unsupported(description: "unexpected path data at '\(scanner.rest)'") }
    }

    private mutating func step(_ command: String, relative: Bool, path: CGMutablePath) throws {
        let origin = relative ? current : .zero
        let previous = control
        control = nil
        switch command {
        case "M":
            current = try scanner.point() + origin
            start = current
            path.move(to: current)
        case "L": current = try scanner.point() + origin; path.addLine(to: current)
        case "H": current.x = try scanner.number() + origin.x; path.addLine(to: current)
        case "V": current.y = try scanner.number() + origin.y; path.addLine(to: current)
        case "C": try curve(try scanner.point() + origin, origin: origin, path: path)
        case "S": try curve(previous.map { current * 2 - $0 } ?? current, origin: origin, path: path)
        case "A": try arc(origin: origin, path: path)
        case "Z": path.closeSubpath(); current = start
        default: throw SVGPath.Unsupported(description: "SVG path command '\(command)' is not supported")
        }
    }

    /// A cubic curve from the current point; `first` is its first control point, already absolute.
    private mutating func curve(_ first: CGPoint, origin: CGPoint, path: CGMutablePath) throws {
        let second = try scanner.point() + origin
        let end = try scanner.point() + origin
        path.addCurve(to: end, control1: first, control2: second)
        control = second
        current = end
    }

    private mutating func arc(origin: CGPoint, path: CGMutablePath) throws {
        let radii = try scanner.point()
        let rotation = try scanner.number() * .pi / 180
        let large = try scanner.flag()
        let sweep = try scanner.flag()
        let end = try scanner.point() + origin
        Arc(from: current, to: end, radii: radii, rotation: rotation).add(to: path, large: large, sweep: sweep)
        current = end
    }
}

/// One elliptical arc segment between two points.
struct Arc {
    let from: CGPoint
    let to: CGPoint
    let radii: CGPoint
    let rotation: CGFloat

    func add(to path: CGMutablePath, large: Bool, sweep: Bool) {
        var (rx, ry) = (abs(radii.x), abs(radii.y))
        guard from != to else { return }
        guard rx > 0, ry > 0 else { path.addLine(to: to); return }
        let (cosine, sine) = (cos(rotation), sin(rotation))
        let half = CGPoint(x: (from.x - to.x) / 2, y: (from.y - to.y) / 2)
        let p = CGPoint(x: cosine * half.x + sine * half.y, y: -sine * half.x + cosine * half.y)
        let lambda = (p.x * p.x) / (rx * rx) + (p.y * p.y) / (ry * ry)
        if lambda > 1 { (rx, ry) = (rx * sqrt(lambda), ry * sqrt(lambda)) }
        let numerator = rx * rx * ry * ry - rx * rx * p.y * p.y - ry * ry * p.x * p.x
        let denominator = rx * rx * p.y * p.y + ry * ry * p.x * p.x
        let coefficient = (large == sweep ? -1 : 1) * sqrt(max(0, numerator / denominator))
        let centre = CGPoint(x: coefficient * rx * p.y / ry, y: -coefficient * ry * p.x / rx)
        let startAngle = Self.angle(CGPoint(x: 1, y: 0), CGPoint(x: (p.x - centre.x) / rx, y: (p.y - centre.y) / ry))
        var delta = Self.angle(
            CGPoint(x: (p.x - centre.x) / rx, y: (p.y - centre.y) / ry), CGPoint(x: (-p.x - centre.x) / rx, y: (-p.y - centre.y) / ry)
        )
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }
        let transform = CGAffineTransform(
            translationX: cosine * centre.x - sine * centre.y + (from.x + to.x) / 2,
            y: sine * centre.x + cosine * centre.y + (from.y + to.y) / 2
        ).rotated(by: rotation).scaledBy(x: rx, y: ry)
        path.addArc(
            center: .zero, radius: 1, startAngle: startAngle, endAngle: startAngle + delta, clockwise: delta < 0, transform: transform
        )
    }

    static func angle(_ u: CGPoint, _ v: CGPoint) -> CGFloat {
        atan2(u.x * v.y - u.y * v.x, u.x * v.x + u.y * v.y)
    }
}

/// Splits path data into commands, numbers and arc flags.
struct PathScanner {
    private let characters: [Character]
    private var index = 0

    init(_ text: String) {
        characters = Array(text)
    }

    var atEnd: Bool { mutating get { skipSeparators(); return index == characters.count } }
    var rest: String { String(characters[index...]) }
    var hasNumber: Bool {
        mutating get {
            skipSeparators()
            guard index < characters.count else { return false }
            return characters[index].isNumber || "+-.".contains(characters[index])
        }
    }

    mutating func command() -> String? {
        skipSeparators()
        guard index < characters.count, characters[index].isLetter else { return nil }
        index += 1
        return String(characters[index - 1])
    }

    mutating func point() throws -> CGPoint {
        CGPoint(x: try number(), y: try number())
    }

    mutating func number() throws -> CGFloat {
        skipSeparators()
        let begin = index
        if index < characters.count, "+-".contains(characters[index]) { index += 1 }
        var dot = false
        while index < characters.count, characters[index].isNumber || (characters[index] == "." && !dot) {
            dot = dot || characters[index] == "."
            index += 1
        }
        guard let value = Double(String(characters[begin..<index])) else {
            throw SVGPath.Unsupported(description: "expected a number at '\(String(characters[begin...]))'")
        }
        return CGFloat(value)
    }

    /// Arc flags are one character, so "01" is two flags.
    mutating func flag() throws -> Bool {
        skipSeparators()
        guard index < characters.count, "01".contains(characters[index]) else {
            throw SVGPath.Unsupported(description: "expected an arc flag 0 or 1")
        }
        index += 1
        return characters[index - 1] == "1"
    }

    private mutating func skipSeparators() {
        while index < characters.count, characters[index].isWhitespace || characters[index] == "," { index += 1 }
    }
}
