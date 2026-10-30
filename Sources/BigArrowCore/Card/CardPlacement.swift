import CoreGraphics

/// Where a card goes, in global top-left points: beside the app's window when there is one, else
/// in a corner of the display, bottom right first: macOS shows notifications top right, over
/// every window. Never over a rect it must keep clear (a target, an arrow's sign)
/// when any candidate can avoid it.
public struct CardPlacement: Sendable {
    public let size: CGSize
    public let display: Display
    public var window: CGRect?
    public var avoid: [CGRect] = []

    public static let gap: CGFloat = 16
    public static let margin: CGFloat = 24

    public init(size: CGSize, display: Display) {
        self.size = size
        self.display = display
    }

    public func origin() -> CGPoint {
        let area = display.visibleFrame.insetBy(dx: Self.margin, dy: Self.margin)
        let rects = candidates(area: area).map { CGRect(origin: $0, size: size) }
        let fits = rects.filter { area.contains($0) }
        let clear = fits.first { rect in !avoid.contains { $0.intersects(rect) } }
        return clear?.origin ?? fits.first?.origin ?? clamp(rects[0], into: area).origin
    }

    /// Beside the window (right, left), inside its top-right corner, then the display's corners.
    /// Next to a window the card starts at the window's top, below the notification banners.
    func candidates(area: CGRect) -> [CGPoint] {
        var points: [CGPoint] = []
        if let window {
            let top = max(window.minY, area.minY)
            points += [
                CGPoint(x: window.maxX + Self.gap, y: top),
                CGPoint(x: window.minX - Self.gap - size.width, y: top),
                CGPoint(x: window.maxX - Self.gap - size.width, y: top + Self.gap)
            ]
        }
        let (right, bottom) = (area.maxX - size.width, area.maxY - size.height)
        points += [
            CGPoint(x: right, y: bottom), CGPoint(x: area.minX, y: bottom),
            CGPoint(x: right, y: area.minY), CGPoint(x: area.minX, y: area.minY)
        ]
        return points
    }

    func clamp(_ rect: CGRect, into area: CGRect) -> CGRect {
        let x = min(max(rect.minX, area.minX), max(area.minX, area.maxX - rect.width))
        let y = min(max(rect.minY, area.minY), max(area.minY, area.maxY - rect.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: rect.size)
    }
}
