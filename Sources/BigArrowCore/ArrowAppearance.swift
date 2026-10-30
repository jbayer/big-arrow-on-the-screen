import Foundation
import CoreGraphics

/// S, M, L presets. Everything that scales with size lives here, nowhere else.
public enum ArrowSize: String, CaseIterable, Sendable, Codable {
    case small = "S"
    case medium = "M"
    case large = "L"

    public var metrics: ArrowMetrics {
        switch self {
        case .small: ArrowMetrics(stroke: 10, headLength: 46, headWidth: 48, fontSize: 30, reach: 130)
        case .medium: ArrowMetrics(stroke: 15, headLength: 62, headWidth: 64, fontSize: 44, reach: 170)
        case .large: ArrowMetrics(stroke: 21, headLength: 84, headWidth: 88, fontSize: 60, reach: 220)
        }
    }

    public static func parse(_ raw: String) throws -> ArrowSize {
        guard let size = ArrowSize(rawValue: raw.uppercased()) else {
            throw BigArrowError.badInput("size '\(raw)' is not one of S, M, L")
        }
        return size
    }
}

public struct ArrowMetrics: Equatable, Sendable {
    public let stroke: CGFloat
    public let headLength: CGFloat
    public let headWidth: CGFloat
    public let fontSize: CGFloat
    /// Preferred distance between the target and the near edge of the sign.
    public let reach: CGFloat

    /// Smallest font the sign shrinks to before giving up on the line limit.
    public static let minimumFontSize: CGFloat = 24
    /// The sign never wraps to more lines than this.
    public static let maximumLines = 3
    /// Share of the display width the sign may use.
    public static let maximumSignWidthShare: CGFloat = 0.6
}

/// How the target is marked.
public enum ArrowStyle: String, CaseIterable, Sendable, Codable {
    case arrow
    case ring
    case box

    public static func parse(_ raw: String) throws -> ArrowStyle {
        guard let style = ArrowStyle(rawValue: raw.lowercased()) else {
            throw BigArrowError.badInput("style '\(raw)' is not one of arrow, ring, box")
        }
        return style
    }
}

/// An sRGB colour, parsed from a preset name or a hex string.
public struct ArrowColor: Equatable, Sendable, Codable {
    public let red: CGFloat
    public let green: CGFloat
    public let blue: CGFloat

    public init(red: CGFloat, green: CGFloat, blue: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = ArrowColor(red: 0, green: 0, blue: 0)

    public static let presets: [(name: String, hex: String)] = [
        ("red", "FF3B1F"), ("orange", "FF8A00"), ("yellow", "FFD60A"), ("green", "21B24B"),
        ("teal", "00B5AD"), ("blue", "0A84FF"), ("purple", "8E44FF"), ("pink", "FF2D78"),
        ("black", "1C1C1E"), ("white", "FFFFFF")
    ]

    public static var accepted: String {
        "a preset (\(presets.map(\.name).joined(separator: ", "))) or hex like #FF3B1F or #F31"
    }

    /// Relative luminance above which the outline and sign text turn dark.
    static let lightThreshold: CGFloat = 0.6

    public static func parse(_ raw: String) throws -> ArrowColor {
        let key = raw.lowercased().trimmingCharacters(in: .whitespaces)
        if let preset = presets.first(where: { $0.name == key }) {
            return try hex(preset.hex)
        }
        do {
            return try hex(key)
        } catch {
            throw BigArrowError.badInput("colour '\(raw)' is not valid, use \(accepted)")
        }
    }

    /// `RRGGBB` or the short `RGB`, with or without `#`.
    private static func hex(_ raw: String) throws -> ArrowColor {
        var digits = raw.hasPrefix("#") ? String(raw.dropFirst()) : raw
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            throw BigArrowError.badInput("not a hex colour")
        }
        return ArrowColor(
            red: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255
        )
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }

    /// `#RRGGBB`, which `parse` reads back.
    public var hex: String {
        let byte = { (value: CGFloat) in Int((value * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
    }

    /// Rec. 709 luma of the sRGB values, good enough to pick a readable contrast colour.
    public var luminance: CGFloat { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

    public var isLight: Bool { luminance > Self.lightThreshold }

    /// Sign text colour: white on dark arrows, near-black on light ones (yellow, white).
    public var contrast: ArrowColor {
        isLight ? ArrowColor(red: 0.11, green: 0.11, blue: 0.12) : ArrowColor(red: 1, green: 1, blue: 1)
    }

    /// Below this luminance a black outline would vanish into the arrow, so it turns white.
    static let darkThreshold: CGFloat = 0.2

    /// The thin outline of `--border black`: black, white on near-black arrows.
    public var outline: ArrowColor {
        luminance < Self.darkThreshold ? ArrowColor(red: 1, green: 1, blue: 1) : ArrowColor(red: 0, green: 0, blue: 0)
    }
}

/// The sign's corners.
public enum SignCorners: String, CaseIterable, Sendable, Codable {
    case round
    case sharp

    /// Corner radius for a sign of `height`: a pill up to 30 pt, or square.
    public func radius(height: CGFloat) -> CGFloat {
        switch self {
        case .round: min(height / 2, 30)
        case .sharp: 0
        }
    }

    public static func parse(_ raw: String) throws -> SignCorners {
        guard let corners = SignCorners(rawValue: raw.lowercased()) else {
            throw BigArrowError.badInput("corners '\(raw)' is not one of round, sharp")
        }
        return corners
    }
}
