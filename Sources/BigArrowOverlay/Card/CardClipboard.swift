import AppKit
import BigArrowCore
import ImageIO
import UniformTypeIdentifiers

/// The general pasteboard, with the nspasteboard.org markers for secrets: clipboard managers and
/// Universal Clipboard skip concealed and transient items (http://nspasteboard.org).
@MainActor
public enum CardClipboard {
    public static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    public static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    /// Puts the value on the clipboard and returns the pasteboard's change count afterwards.
    @discardableResult
    public static func copy(_ value: String, secret: Bool) -> Int {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        if secret {
            pasteboard.setData(Data(), forType: concealed)
            pasteboard.setData(Data(), forType: transient)
        }
        return pasteboard.changeCount
    }

    /// Empties the clipboard only if it still holds what we put there.
    public static func clear(ifUnchangedSince changeCount: Int) -> Bool {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == changeCount else { return false }
        pasteboard.clearContents()
        return true
    }
}

/// Renders a card into a PNG without a window (`--png`), for tests, docs and the gallery.
@MainActor
public enum CardPNG {
    public static func write(_ view: CardView, theme: String?, scale: CGFloat, to url: URL) throws {
        view.appearance = CardController.appearance(theme) ?? NSAppearance(named: .aqua)
        let size = view.fittingSize
        view.frame = CGRect(origin: .zero, size: size)
        view.layoutSubtreeIfNeeded()
        view.layout()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            throw BigArrowError.badInput("cannot render the card (\(Int(size.width))x\(Int(size.height)))")
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = try scaled(rep, scale: scale)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw BigArrowError.badInput("cannot write a PNG to \(url.path)")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw BigArrowError.badInput("cannot write a PNG to \(url.path)") }
    }

    /// The cached bitmap at `scale` pixels per point, with the card's rounded corners transparent.
    static func scaled(_ rep: NSBitmapImageRep, scale: CGFloat) throws -> CGImage {
        let size = rep.size
        let canvas = Canvas(size: size, scale: scale)
        return canvas.render { context in
            let path = CGPath(roundedRect: CGRect(origin: .zero, size: size), cornerWidth: CardStyle.corner,
                              cornerHeight: CardStyle.corner, transform: nil)
            context.addPath(path)
            context.clip()
            guard let image = rep.cgImage else { return }
            context.draw(image, in: CGRect(origin: .zero, size: size))
        }
    }
}
