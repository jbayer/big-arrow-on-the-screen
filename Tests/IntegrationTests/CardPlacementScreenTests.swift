import AppKit
import BigArrowCore
import BigArrowOverlay
import Foundation
import Testing

/// A card with an `app` sits beside that app's front window, on the real window server.
@Suite(
    "Card beside its app", .serialized,
    .enabled(if: ProcessInfo.processInfo.environment["BIGARROW_SCREEN_TESTS"] == "1", "set BIGARROW_SCREEN_TESTS=1 to draw on screen")
)
struct CardPlacementScreenTests {
    /// An app with a visible window, that window's frame (picked the way the CLI picks it) and
    /// the area a card may use.
    struct Home {
        let app: String
        let window: CGRect
        let area: CGRect
    }

    static func home() async -> Home? {
        await MainActor.run { () -> Home? in
            let pids = Set(WindowServer.visibleAppWindowOwners())
            let running = NSWorkspace.shared.runningApplications
            guard let name = running.first(where: { pids.contains($0.processIdentifier) && $0.localizedName != nil })?.localizedName
            else { return nil }
            let apps = running.map { RunningAppInfo(pid: $0.processIdentifier, name: $0.localizedName, bundleID: $0.bundleIdentifier) }
            let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
            let all = (CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []).compactMap(WindowServer.windowInfo)
            let displays = ScreenReader.current().displays
            let matched = WindowMatcher.apps(matching: name, in: apps).map(\.pid)
            guard let window = WindowMatcher.windows(of: matched, in: all, title: nil, displays: displays).first else { return nil }
            let area = displays[0].visibleFrame.insetBy(dx: CardPlacement.margin, dy: CardPlacement.margin)
            return Home(app: name, window: WindowMatcher.visiblePart(of: window, on: displays), area: area)
        }
    }

    @Test("The card starts right of the app's window when it fits there")
    func besideWindow() async throws {
        guard let home = await Self.home() else {
            print("skipped: no app with a visible window")
            return
        }
        let result = try BigArrowProcess.run(["card", "--title", "Placement test", "--note", "x", "--app", home.app])
        #expect(result.code == 0, "\(result.stderr)")
        let json = try result.json()
        if let pid = json["pid"] as? Int { _ = try BigArrowProcess.run(["stop", "--pid", String(pid)]) }
        let card = try #require(json["card"] as? [Double])
        let window = home.window
        let right = CGRect(x: window.maxX + CardPlacement.gap, y: max(window.minY, home.area.minY), width: card[2], height: card[3])
        guard home.area.contains(right) else {
            print("skipped: \(home.app)'s window leaves no room on its right")
            return
        }
        #expect(card[0] == right.minX && card[1] == right.minY, "card \(card), window \(window)")
    }
}
