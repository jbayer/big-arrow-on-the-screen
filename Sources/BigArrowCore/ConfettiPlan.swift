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

/// Confetti over a whole display: pieces start just above its top edge across the full width,
/// fall over the whole height with gravity and spin, and the last ones land as `duration` ends.
/// Pure numbers, so the plan is testable without a window server.
public struct ConfettiPlan: Equatable, Sendable {
    /// Seconds of confetti when no duration is given.
    public static let defaultDuration: TimeInterval = 5
    /// Confetti never outlives this, whatever is asked for.
    public static let maximumDuration: TimeInterval = 30
    /// Pieces per second on a 1,000 pt wide display; wider displays get proportionally more.
    static let piecesPerThousandPoints: Double = 220
    /// Downward pull in points per second squared.
    public static let gravity: CGFloat = 420
    public static let initialSpeed: CGFloat = 180
    public static let colors: [ArrowColor] = ArrowColor.presets.filter { $0.name != "black" && $0.name != "white" }
        .compactMap { try? ArrowColor.parse($0.hex) }

    public let size: CGSize
    public let duration: TimeInterval
    /// Seconds pieces are born; they then fall until they leave the display.
    public let burst: TimeInterval
    /// Seconds a piece lives: long enough to fall from the top edge past the bottom edge.
    public let lifetime: TimeInterval
    /// All pieces born per second, over every colour and shape.
    public let piecesPerSecond: Double

    public init(display size: CGSize, duration: TimeInterval = Self.defaultDuration) throws {
        guard duration.isFinite, duration > 0, duration <= Self.maximumDuration else {
            throw BigArrowError.badInput("--duration for confetti must be more than 0 and at most \(Int(Self.maximumDuration)) s")
        }
        self.size = size
        self.duration = duration
        lifetime = Self.fallTime(height: size.height + 60)
        // The last pieces land just as the time is up; a very short duration still gets a puff,
        // which the fade-out at the end takes away mid-air.
        burst = min(duration, max(0.4, duration - lifetime))
        piecesPerSecond = Self.piecesPerThousandPoints * Double(size.width) / 1000
    }

    /// Seconds to fall `height` points from `initialSpeed` under `gravity`, with 15 % to spare.
    static func fallTime(height: CGFloat) -> TimeInterval {
        let (a, v) = (Double(gravity) / 2, Double(initialSpeed))
        let t = (-v + (v * v + 4 * a * Double(height)).squareRoot()) / (2 * a)
        return t * 1.15
    }

    /// Births per second for each of the colour x shape cells.
    public var birthRatePerCell: Float {
        Float(piecesPerSecond / Double(Self.colors.count * ConfettiPiece.allCases.count))
    }

    /// About how many pieces fly in total.
    public var totalPieces: Int { Int((piecesPerSecond * burst).rounded()) }
}
