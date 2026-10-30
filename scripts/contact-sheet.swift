// Lays PNGs out on a light grid with a caption under each: contact-sheet <out.png> <columns> <cell-width> <file:caption>...
import AppKit

let arguments = CommandLine.arguments
guard arguments.count > 4, let columns = Int(arguments[2]), let cellWidth = Double(arguments[3]) else {
    FileHandle.standardError.write(Data("usage: contact-sheet <out.png> <columns> <cell-width> <file:caption>...\n".utf8))
    exit(2)
}
let items = arguments.dropFirst(4).map { entry -> (NSImage, String) in
    let parts = entry.split(separator: ":", maxSplits: 1).map(String.init)
    guard let image = NSImage(contentsOfFile: parts[0]) else {
        FileHandle.standardError.write(Data("cannot read \(parts[0])\n".utf8))
        exit(1)
    }
    return (image, parts.count > 1 ? parts[1] : "")
}
let width = CGFloat(cellWidth)
// CELL_ASPECT: cell height as a share of its width (default 0.62; tall cue cards need more).
let height = width * (Double(ProcessInfo.processInfo.environment["CELL_ASPECT"] ?? "") ?? 0.62)
let caption: CGFloat = 26
let rows = (items.count + columns - 1) / columns
let size = NSSize(width: width * CGFloat(columns), height: (height + caption) * CGFloat(rows))
let sheet = NSImage(size: size, flipped: true) { _ in
    NSColor(white: 0.94, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()
    for (index, (image, text)) in items.enumerated() {
        let origin = CGPoint(x: CGFloat(index % columns) * width, y: CGFloat(index / columns) * (height + caption))
        let cell = NSRect(x: origin.x, y: origin.y, width: width, height: height).insetBy(dx: 10, dy: 8)
        let scale = min(cell.width / image.size.width, cell.height / image.size.height)
        let drawn = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: NSRect(x: cell.midX - drawn.width / 2, y: cell.midY - drawn.height / 2, width: drawn.width, height: drawn.height))
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: NSColor.darkGray]
        text.draw(at: CGPoint(x: origin.x + 12, y: origin.y + height), withAttributes: attributes)
    }
    return true
}
guard let tiff = sheet.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: arguments[1]))
