// Renders a PDF as a viewer window: every page as a thumbnail on the left, the first page large on
// the right, drawn offscreen with PDFKit (vector, at 2x), so no app opens and no screen is touched.
// usage: pdf-preview <in.pdf> <out.png>
import AppKit
import PDFKit

let args = CommandLine.arguments
guard args.count == 3, let document = PDFDocument(url: URL(fileURLWithPath: args[1])), document.pageCount > 0,
      let firstPage = document.page(at: 0) else {
    FileHandle.standardError.write(Data("usage: pdf-preview <in.pdf> <out.png>\n".utf8))
    exit(2)
}

let scale: CGFloat = 2
let titleBar: CGFloat = 52
let sidebar: CGFloat = 170
let pageHeight: CGFloat = 1000
let margin: CGFloat = 40
let pageBox = firstPage.bounds(for: .mediaBox)
let pageWidth = pageHeight * pageBox.width / pageBox.height
let windowSize = NSSize(width: sidebar + pageWidth + 2 * margin, height: titleBar + pageHeight + 2 * margin)
let canvas = NSSize(width: windowSize.width + 2 * margin, height: windowSize.height + 2 * margin)
let window = NSRect(x: margin, y: margin, width: windowSize.width, height: windowSize.height)

/// A rect given from the window's top-left corner, in the unflipped canvas.
func fromTop(_ x: CGFloat, _ top: CGFloat, _ size: NSSize) -> NSRect {
    NSRect(x: window.minX + x, y: window.maxY - top - size.height, width: size.width, height: size.height)
}

func drawPage(_ page: PDFPage, in rect: NSRect, context: CGContext) {
    let box = page.bounds(for: .mediaBox)
    NSColor.white.setFill()
    rect.fill()
    context.saveGState()
    context.translateBy(x: rect.minX, y: rect.minY)
    context.scaleBy(x: rect.width / box.width, y: rect.height / box.height)
    page.draw(with: .mediaBox, to: context)
    context.restoreGState()
}

func withShadow(blur: CGFloat, offset: CGFloat, alpha: CGFloat, _ draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = blur
    shadow.shadowOffset = NSSize(width: 0, height: -offset)
    shadow.shadowColor = NSColor(white: 0, alpha: alpha)
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

func drawFrame() {
    let shape = NSBezierPath(roundedRect: window, xRadius: 14, yRadius: 14)
    withShadow(blur: 30, offset: 12, alpha: 0.35) {
        NSColor(white: 0.86, alpha: 1).setFill()
        shape.fill()
    }
    shape.addClip()
    NSColor(white: 0.93, alpha: 1).setFill()
    fromTop(0, 0, NSSize(width: window.width, height: titleBar)).fill()
    NSColor(white: 0.965, alpha: 1).setFill()
    fromTop(0, titleBar, NSSize(width: sidebar, height: window.height - titleBar)).fill()
    NSColor(white: 0.8, alpha: 1).setFill()
    fromTop(0, titleBar - 1, NSSize(width: window.width, height: 1)).fill()
    fromTop(sidebar, titleBar, NSSize(width: 1, height: window.height - titleBar)).fill()
    for (index, hex) in [0xFF5F57, 0xFEBC2E, 0x28C840].enumerated() {
        color(hex).setFill()
        NSBezierPath(ovalIn: fromTop(20 + CGFloat(index) * 20, 20, NSSize(width: 12, height: 12))).fill()
    }
}

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func drawTitle(_ name: String) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let title = NSMutableAttributedString(string: name, attributes: [
        .font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(white: 0.15, alpha: 1), .paragraphStyle: style])
    title.append(NSAttributedString(string: "\nPage 1 of \(document.pageCount)", attributes: [
        .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(white: 0.45, alpha: 1), .paragraphStyle: style]))
    title.draw(in: fromTop(sidebar, 9, NSSize(width: window.width - sidebar, height: 40)))
}

func drawThumbnails(context: CGContext) {
    let slot = (window.height - titleBar - 16) / CGFloat(document.pageCount)
    let height = slot - 30
    let size = NSSize(width: height * pageBox.width / pageBox.height, height: height)
    let label: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor(white: 0.4, alpha: 1)]
    for index in 0..<document.pageCount {
        guard let page = document.page(at: index) else { continue }
        let rect = fromTop((sidebar - size.width) / 2, titleBar + 12 + CGFloat(index) * slot, size)
        if index == 0 {
            color(0x0A84FF).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: -5, dy: -5), xRadius: 6, yRadius: 6).fill()
        }
        withShadow(blur: 3, offset: 1, alpha: 0.3) { NSColor.white.setFill(); rect.fill() }
        drawPage(page, in: rect, context: context)
        let number = NSAttributedString(string: "\(index + 1)", attributes: label)
        number.draw(at: NSPoint(x: rect.midX - number.size().width / 2, y: rect.minY - 22))
    }
}

func render() -> NSBitmapImageRep? {
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width * scale), pixelsHigh: Int(canvas.height * scale),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
    bitmap.size = canvas
    NSGraphicsContext.current = graphics
    let context = graphics.cgContext
    context.scaleBy(x: scale, y: scale)
    drawFrame()
    drawTitle(URL(fileURLWithPath: args[1]).lastPathComponent)
    drawThumbnails(context: context)
    let main = fromTop(sidebar + margin, titleBar + margin, NSSize(width: pageWidth, height: pageHeight))
    withShadow(blur: 12, offset: 3, alpha: 0.3) { NSColor.white.setFill(); main.fill() }
    drawPage(firstPage, in: main, context: context)
    graphics.flushGraphics()
    return bitmap
}

guard let bitmap = render(), let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[2]))
