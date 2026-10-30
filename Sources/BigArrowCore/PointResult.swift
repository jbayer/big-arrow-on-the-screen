import CoreGraphics
import Foundation

/// Why an arrow went away.
public enum DismissReason: String, Codable, Sendable {
    case timeout, signal, clicked, closed, targetGone, displayGone, ownerGone
}

/// The `--json` result of `bigarrow point`.
public struct PointResult: Codable, Sendable {
    public struct Target: Codable, Sendable {
        public let x: Double
        public let y: Double
        public let display: Int
        public let source: String
        public let detail: [String: String]
        public let rect: [Double]?
    }

    public var ok = true
    public let pid: Int32
    public let target: Target
    /// Sign frame in global top-left points: x, y, width, height.
    public var sign: [Double]
    public var direction: String
    public var detached = false
    public var dryRun = false
    public var dismissedAfter: Double?
    public var dismissedReason: DismissReason?
    /// Every `{{value}}` copy chip in the sign, global top-left points: x, y, width, height.
    public var copyButtons: [[Double]]?
    /// How often the human clicked a copy button in the sign; nil when never.
    public var copied: Int?
    /// With `--png`: the image's top-left corner in global points and its pixels per point.
    public var image: [Double]?

    public init(pid: Int32, resolved: ResolvedTarget, layout: OverlayLayout) {
        let anchor = resolved.shape.anchor
        let display = layout.display
        let sign = layout.signRect.offsetBy(dx: display.frame.minX, dy: display.frame.minY)
        self.pid = pid
        self.target = Target(
            x: anchor.x, y: anchor.y, display: display.index + 1, source: resolved.source,
            detail: resolved.detail, rect: resolved.shape.rect.map { [$0.minX, $0.minY, $0.width, $0.height] }
        )
        self.sign = [sign.minX, sign.minY, sign.width, sign.height]
        self.direction = layout.direction.rawValue
    }
}

/// The `--json` error object, also used for every non-zero exit.
public struct ErrorResult: Codable, Sendable {
    public var ok = false
    public let code: Int32
    public let error: String

    public init(_ error: BigArrowError) {
        self.code = error.code.rawValue
        self.error = error.message
    }
}

public enum JSONOutput {
    public static func encode<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else {
            preconditionFailure("encoding \(T.self) to JSON failed")
        }
        return text
    }
}
