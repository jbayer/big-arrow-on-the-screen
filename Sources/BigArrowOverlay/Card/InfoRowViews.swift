import AppKit
import BigArrowCore
import CoreImage

/// Rows that show something: `text` (inline Markdown), `progress`, `qr`, `image` and `file`.
@MainActor
enum InfoRows {
    static let qrSize: CGFloat = 200
    static let imageMaxHeight: CGFloat = 260

    static func text(_ row: CardRow) -> NSView {
        let field = CardStyle.label("", font: CardStyle.bodyFont)
        field.attributedStringValue = CardStyle.markdown(row.value ?? "", font: CardStyle.bodyFont)
        field.allowsEditingTextAttributes = true
        field.isSelectable = true
        return AnswerRows.withLabel(row.label, field)
    }

    static func progress(_ row: CardRow, style: CardStyle) -> NSView {
        var parts: [NSView] = []
        if let value = row.value { parts.append(CardStyle.label(value, font: CardStyle.bodyFont)) }
        if let fraction = row.progress { parts.append(ProgressBar(fraction: fraction, style: style)) }
        let stack = Stack.vertical(parts, spacing: 8)
        parts.last.map { $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        return AnswerRows.withLabel(row.label, stack)
    }

    static func qr(_ row: CardRow) throws -> NSView {
        let view = NSImageView(image: try qrImage(row.value ?? ""))
        view.imageScaling = .scaleProportionallyUpOrDown
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: qrSize).isActive = true
        view.heightAnchor.constraint(equalToConstant: qrSize).isActive = true
        return AnswerRows.withLabel(row.label, centred(view))
    }

    static func image(_ row: CardRow) throws -> NSView {
        let path = NSString(string: row.path ?? "").expandingTildeInPath
        guard let image = NSImage(contentsOfFile: path), image.size.width > 0 else {
            throw BigArrowError.badInput("card image \(path) cannot be read")
        }
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyDown
        let width = CardStyle.width - CardStyle.padding * 2
        let height = min(imageMaxHeight, width * image.size.height / image.size.width)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return AnswerRows.withLabel(row.label, centred(view))
    }

    static func centred(_ view: NSView) -> NSView {
        let line = Stack.horizontal([NSView(), view, NSView()], spacing: 0)
        line.distribution = .equalCentering
        return line
    }

    /// Black modules on white with the quiet zone, scaled without smoothing so it scans.
    static func qrImage(_ text: String) throws -> NSImage {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw BigArrowError.badInput("Core Image has no QR code generator")
        }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let image = CIContext().createCGImage(output, from: output.extent) else {
            throw BigArrowError.badInput("the QR code value is too long (\(text.utf8.count) bytes)")
        }
        return NSImage(cgImage: image, size: CGSize(width: qrSize, height: qrSize))
    }
}

/// A rounded bar in the card colour on a faint track, drawn by itself so offscreen renders show it.
@MainActor
final class ProgressBar: NSView {
    let fraction: Double
    let style: CardStyle

    init(fraction: Double, style: CardStyle) {
        self.fraction = fraction
        self.style = style
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 12).isActive = true
        setAccessibilityRole(.progressIndicator)
        setAccessibilityValue(fraction)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    override func draw(_ dirtyRect: NSRect) {
        let radius = bounds.height / 2
        style.tint.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius).fill()
        let filled = NSRect(x: 0, y: 0, width: max(bounds.height, bounds.width * fraction), height: bounds.height)
        style.tint.setFill()
        NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
    }
}

/// A file the human drags out of the card onto an upload field or into Finder.
@MainActor
final class FileRowView: NSView, NSDraggingSource {
    let url: URL
    let events: CardEvents

    init(row: CardRow, style: CardStyle, events: CardEvents) throws {
        url = URL(fileURLWithPath: NSString(string: row.path ?? "").expandingTildeInPath)
        self.events = events
        super.init(frame: .zero)
        guard FileManager.default.fileExists(atPath: url.path) else { throw BigArrowError.badInput("card file \(url.path) does not exist") }
        let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: url.path))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 48).isActive = true
        let name = CardStyle.label(url.lastPathComponent, font: CardStyle.valueFont)
        name.maximumNumberOfLines = 1
        name.lineBreakMode = .byTruncatingMiddle
        let size = ByteCountFormatter.string(fromByteCount: Self.size(of: url), countStyle: .file)
        let hint = CardStyle.label("\(size) - drag it where it goes", font: CardStyle.detailFont, color: .secondaryLabelColor)
        let reveal = ActionButton(icon: .file, tint: style.tint, tooltip: "Show in Finder") { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.activateFileViewerSelecting([self.url])
        }
        let line = Stack.horizontal([icon, Stack.vertical([name, hint], spacing: 2), NSView(), reveal], spacing: 12)
        RowLayout.fill(self, with: AnswerRows.withLabel(row.label, line))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { preconditionFailure("cards are built in code") }

    static func size(of url: URL) -> Int64 {
        ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? NSNumber)?.int64Value ?? 0
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let image = NSWorkspace.shared.icon(forFile: url.path)
        let location = convert(event.locationInWindow, from: nil)
        item.setDraggingFrame(CGRect(x: location.x - 24, y: location.y - 24, width: 48, height: 48), contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    nonisolated func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}
