import CoreGraphics
import Foundation

/// The shape of one confetti piece.
public enum ConfettiPiece: CaseIterable, Sendable {
    case strip
    case square
    case dot

    /// Size in points; pieces are white images tinted by their cell's colour.
    public var size: CGSize {
        switch self {
        case .strip: CGSize(width: 14, height: 6)
        case .square: CGSize(width: 9, height: 9)
        case .dot: CGSize(width: 8, height: 8)
        }
    }
}

/// Confetti over a whole display from every side: cannons in both bottom corners, on both side
/// edges and along the bottom shoot pieces up and inwards, and a rain falls from the top edge.
/// Pure numbers in the display's bottom-left points (the panel's layer space), so the plan is
/// testable without a window server.
public struct ConfettiPlan: Equatable, Sendable {
    /// Seconds of confetti when no duration is given.
    public static let defaultDuration: TimeInterval = 5
    /// Confetti never outlives this, whatever is asked for.
    public static let maximumDuration: TimeInterval = 30
    public static let colors: [ArrowColor] = ArrowColor.presets.filter { $0.name != "black" && $0.name != "white" }
        .compactMap { try? ArrowColor.parse($0.hex) }

    public let size: CGSize
    public let duration: TimeInterval
    public let sources: [ConfettiSource]

    public init(display size: CGSize, duration: TimeInterval = Self.defaultDuration) throws {
        guard duration.isFinite, duration > 0, duration <= Self.maximumDuration else {
            throw BigArrowError.badInput("--duration for confetti must be more than 0 and at most \(Int(Self.maximumDuration)) s")
        }
        self.size = size
        self.duration = duration
        sources = ConfettiSource.all(in: size, duration: duration)
    }

    /// About how many pieces fly in total.
    public var totalPieces: Int {
        Int(sources.map { $0.piecesPerSecond * $0.burst }.reduce(0, +).rounded())
    }
}

/// One emitter: where it sits, where it shoots, how hard, for how long.
public struct ConfettiSource: Equatable, Sendable {
    /// Start point in bottom-left display points; a line source is centred on it.
    public let position: CGPoint
    /// Length of a line source; 0 for a point.
    public let width: CGFloat
    /// Direction in radians: 0 right, pi/2 up, -pi/2 down.
    public let angle: CGFloat
    public let spread: CGFloat
    public let speed: CGFloat
    /// How much faster or slower a piece may fly, as a share of `speed`.
    public static let speedRange: CGFloat = 0.2
    /// Downward pull in points per second squared.
    public let gravity: CGFloat
    public let piecesPerSecond: Double
    /// Seconds pieces are born.
    public let burst: TimeInterval
    /// Seconds a piece lives: long enough for the fastest one to fall out past the bottom edge.
    public let lifetime: TimeInterval

    static let rainGravity: CGFloat = 420
    static let cannonGravity: CGFloat = 650
    static let cannonBurst: TimeInterval = 0.6
    static let minimumBurst: TimeInterval = 0.2

    /// Rain, both bottom corners, both sides and the bottom middle.
    static func all(in size: CGSize, duration: TimeInterval) -> [ConfettiSource] {
        let (w, h) = (size.width, size.height)
        let perWidth = Double(w) / 1000
        let cannons = [
            Shot(position: CGPoint(x: 0, y: 0), width: 0, angle: .pi * 0.36, spread: .pi / 9),
            Shot(position: CGPoint(x: w, y: 0), width: 0, angle: .pi * 0.64, spread: .pi / 9),
            Shot(position: CGPoint(x: 0, y: h * 0.45), width: 0, angle: .pi / 6, spread: .pi / 10),
            Shot(position: CGPoint(x: w, y: h * 0.45), width: 0, angle: .pi * 5 / 6, spread: .pi / 10),
            Shot(position: CGPoint(x: w / 2, y: -10), width: w / 3, angle: .pi / 2, spread: .pi / 7)
        ]
        let cannonRates: [Double] = [260, 260, 160, 160, 200]
        var rain = Shot(position: CGPoint(x: w / 2, y: h + 30), width: w * 1.1, angle: -.pi / 2, spread: .pi / 4)
        rain.rate = 160 * perWidth
        let rainSource = rain.source(speed: 180, gravity: rainGravity, duration: duration, burst: nil)
        return [rainSource] + zip(cannons, cannonRates).map { cannon, rate in
            var shot = cannon
            shot.rate = rate * perWidth
            // The apex: 60 % of the display above the bottom, a quarter above a side cannon.
            let rise = shot.position.y > 0 ? h * 0.25 : h * 0.6
            let speed = (2 * cannonGravity * rise).squareRoot() / sin(shot.angle)
            return shot.source(speed: speed, gravity: cannonGravity, duration: duration, burst: cannonBurst)
        }
    }
}

/// Where a source sits and where it aims, before its speed and timing are worked out.
struct Shot {
    let position: CGPoint
    let width: CGFloat
    let angle: CGFloat
    let spread: CGFloat
    /// Pieces per second.
    var rate: Double = 0

    /// `burst` nil: born for as long as the last piece still lands before `duration` ends.
    func source(speed: CGFloat, gravity: CGFloat, duration: TimeInterval, burst: TimeInterval?) -> ConfettiSource {
        let life = lifetime(speed: speed, gravity: gravity)
        let wanted = burst ?? duration - life
        let fitted = min(duration, max(ConfettiSource.minimumBurst, min(wanted, duration - life)))
        return ConfettiSource(
            position: position, width: width, angle: angle, spread: spread, speed: speed, gravity: gravity,
            piecesPerSecond: rate, burst: fitted, lifetime: life
        )
    }

    /// Seconds until the slowest piece to land, falls 30 pt below the bottom edge: for a cannon the
    /// fastest one shot closest to straight up, for the rain the slowest one shot most sideways.
    /// The cone counts as `spread` to either side, more than Core Animation uses, so it is never short.
    func lifetime(speed: CGFloat, gravity: CGFloat) -> TimeInterval {
        let (lo, hi) = (Double(angle - spread), Double(angle + spread))
        let vertical: Double
        if angle > 0 {
            let steepest = min(max(Double.pi / 2, lo), hi)
            vertical = Double(speed * (1 + ConfettiSource.speedRange)) * sin(steepest)
        } else {
            vertical = -Double(speed * (1 - ConfettiSource.speedRange)) * max(0, -sin(hi))
        }
        let drop = Double(position.y) + 30
        let g = Double(gravity)
        return (vertical + (vertical * vertical + 2 * g * drop).squareRoot()) / g * 1.05
    }
}
