// Test helper for scripts/behaviour-check.sh, run only on a disposable machine (CI runner):
//   testkit click X Y                posts a left click at global top-left point X,Y
//   testkit glide X Y SECONDS        moves the pointer there smoothly, like a hand (for recordings)
//   testkit scroll X Y LINES         scrolls the wheel over X,Y, LINES > 0 scrolls the content down
//   testkit move-window APP X Y      moves APP's first window to X,Y via Accessibility (APP may be 'frontmost')
//   testkit resize-window APP W H    resizes APP's first window via Accessibility
//   testkit frontmost                prints the frontmost app's name
//   testkit activate APP             brings APP to the front
//   testkit windows APP|PID          prints APP's (or that process's) windows as the window server lists them
//   testkit pixel X Y                prints the screen colour at X,Y as "r g b" (0-255)
//   testkit cpu PID SECONDS          prints the CPU share PID used over SECONDS, in percent
//   testkit type TEXT                types TEXT into the focused field, then Return with --return
//   testkit pasteboard               prints the clipboard's types, one per line, then its string
import AppKit
import ApplicationServices

func app(named name: String) -> NSRunningApplication {
    if name == "frontmost", let front = NSWorkspace.shared.frontmostApplication { return front }
    guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) else {
        FileHandle.standardError.write(Data("testkit: no app named \(name)\n".utf8))
        exit(1)
    }
    return app
}

/// Moves the pointer first and pauses like a hand would, then clicks: bigarrow makes its sign
/// clickable only while the pointer is over it.
func click(_ point: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(150_000)
    for type in [CGEventType.leftMouseDown, .leftMouseUp] {
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(80_000)
    }
}

/// Eases the pointer from where it is to the point in 60 steps per second.
func glide(to point: CGPoint, seconds: Double) {
    let start = CGEvent(source: nil)?.location ?? point
    let steps = max(Int(seconds * 60), 1)
    for step in 1...steps {
        let t = Double(step) / Double(steps), eased = t * t * (3 - 2 * t)
        let at = CGPoint(x: start.x + (point.x - start.x) * eased, y: start.y + (point.y - start.y) * eased)
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: at, mouseButton: .left)?.post(tap: .cghidEventTap)
        usleep(useconds_t(seconds / Double(steps) * 1_000_000))
    }
}

/// One wheel line at a time, so the list moves visibly instead of jumping.
func scroll(at point: CGPoint, lines: Int) {
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
    for _ in 0..<abs(lines) {
        CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: lines > 0 ? -1 : 1, wheel2: 0, wheel3: 0)?.post(tap: .cghidEventTap)
        usleep(60_000)
    }
}

/// Types like a keyboard: one Unicode key event per character.
func type(_ text: String, pressReturn: Bool) {
    for character in text.utf16 {
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down)
            event?.keyboardSetUnicodeString(stringLength: 1, unicodeString: [character])
            event?.post(tap: .cghidEventTap)
            usleep(20_000)
        }
    }
    guard pressReturn else { return }
    for down in [true, false] {
        CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: down)?.post(tap: .cghidEventTap)
        usleep(20_000)
    }
}

func firstWindow(of name: String) -> AXUIElement {
    let element = AXUIElementCreateApplication(app(named: name).processIdentifier)
    var windows: CFTypeRef?
    AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &windows)
    guard let window = (windows as? [AXUIElement])?.first else { exit(1) }
    return window
}

func moveWindow(of name: String, to point: CGPoint) {
    var position = point
    guard let value = AXValueCreate(.cgPoint, &position) else { exit(1) }
    exit(AXUIElementSetAttributeValue(firstWindow(of: name), kAXPositionAttribute as CFString, value) == .success ? 0 : 1)
}

func resizeWindow(of name: String, to size: CGSize) {
    var extent = size
    guard let value = AXValueCreate(.cgSize, &extent) else { exit(1) }
    exit(AXUIElementSetAttributeValue(firstWindow(of: name), kAXSizeAttribute as CFString, value) == .success ? 0 : 1)
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "click": click(CGPoint(x: Double(args[2]) ?? 0, y: Double(args[3]) ?? 0))
case "glide": glide(to: CGPoint(x: Double(args[2]) ?? 0, y: Double(args[3]) ?? 0), seconds: Double(args[4]) ?? 0.8)
case "scroll": scroll(at: CGPoint(x: Double(args[2]) ?? 0, y: Double(args[3]) ?? 0), lines: Int(args[4]) ?? 3)
case "move-window": moveWindow(of: args[2], to: CGPoint(x: Double(args[3]) ?? 0, y: Double(args[4]) ?? 0))
case "windows":
    let pid = Int32(args[2]) ?? app(named: args[2]).processIdentifier
    let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    for entry in list where entry[kCGWindowOwnerPID as String] as? Int32 == pid {
        let keys = [kCGWindowNumber, kCGWindowLayer, kCGWindowBounds, kCGWindowIsOnscreen, kCGWindowAlpha, kCGWindowName]
        print(keys.map { "\($0 as String)=\(entry[$0 as String] ?? "-")" }.joined(separator: " ").replacingOccurrences(of: "\n", with: ""))
    }
case "pixel":
    let file = "/tmp/testkit-pixel.png"
    let capture = Process()
    capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    capture.arguments = ["-x", "-R", "\(args[2]),\(args[3]),1,1", file]
    try? capture.run()
    capture.waitUntilExit()
    guard let image = NSImage(contentsOfFile: file), let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff), let color = bitmap.colorAt(x: 0, y: 0)?.usingColorSpace(.sRGB) else { exit(1) }
    print(Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
case "cpu":
    let pid = args[2]
    let seconds = Double(args[3]) ?? 5
    func cpuTime() -> Double {
        let ps = Process()
        let pipe = Pipe()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "cputime=", "-p", pid]
        ps.standardOutput = pipe
        try? ps.run()
        ps.waitUntilExit()
        let text = String(bytes: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":").compactMap { Double($0) }
        return parts.reduce(0) { $0 * 60 + $1 }
    }
    let start = cpuTime()
    Thread.sleep(forTimeInterval: seconds)
    print(String(format: "%.2f", (cpuTime() - start) / seconds * 100))
case "resize-window": resizeWindow(of: args[2], to: CGSize(width: Double(args[3]) ?? 800, height: Double(args[4]) ?? 600))
case "type": type(args[2], pressReturn: args.contains("--return"))
case "pasteboard":
    let pasteboard = NSPasteboard.general
    (pasteboard.types ?? []).forEach { print($0.rawValue) }
    print(pasteboard.string(forType: .string) ?? "")
case "frontmost": print(NSWorkspace.shared.frontmostApplication?.localizedName ?? "")
case "activate":
    app(named: args[2]).activate()
    RunLoop.main.run(until: Date().addingTimeInterval(1))
default:
    FileHandle.standardError.write(Data("usage: testkit click|move-window|frontmost|activate ...\n".utf8))
    exit(2)
}
