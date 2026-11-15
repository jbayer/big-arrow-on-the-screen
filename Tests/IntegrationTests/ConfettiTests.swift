import AppKit
import CoreGraphics
import Foundation
import Testing

/// `bigarrow confetti` through the real binary: planning without drawing always, the real
/// window server only with `BIGARROW_SCREEN_TESTS=1`.
@Suite("Confetti")
struct ConfettiTests {
    @Test("--dry-run plans every display and draws nothing")
    func dryRun() async throws {
        let result = try BigArrowProcess.run(["confetti", "--dry-run", "--json"])
        #expect(result.code == 0, "\(result.stderr)")
        let json = try result.json()
        let displays = try #require(json["displays"] as? [Int])
        let count = await MainActor.run { NSScreen.screens.count }
        #expect(displays == Array(1...count))
        #expect((json["pieces"] as? Int ?? 0) > 0)
        #expect(json["dryRun"] as? Bool == true)
    }

    @Test("A missing display and a duration above 30 s exit 2")
    func badInput() throws {
        #expect(try BigArrowProcess.run(["confetti", "--display", "99", "--dry-run"]).code == 2)
        #expect(try BigArrowProcess.run(["confetti", "--duration", "31", "--dry-run"]).code == 2)
    }

    @Test(
        "Confetti covers each display with a click-through layer-1000 window, keeps the focus and ends by itself",
        .enabled(if: ProcessInfo.processInfo.environment["BIGARROW_SCREEN_TESTS"] == "1", "set BIGARROW_SCREEN_TESTS=1 to draw on screen")
    )
    func onScreen() async throws {
        let reduced = await MainActor.run { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        guard !reduced else {
            print("skipped: Reduce Motion is on, confetti is skipped by design")
            return
        }
        let frontBefore = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        let detached = try BigArrowProcess.run(["confetti", "--duration", "2", "--detach", "--json"])
        #expect(detached.code == 0, "\(detached.stderr)")
        let pid = try #require(detached.json()["pid"] as? Int32)
        let windows = WindowServer.waitForWindows(of: pid)
        let frames = await MainActor.run { NSScreen.screens.map(\.frame.size) }
        #expect(windows.count == frames.count)
        #expect(windows.allSatisfy { $0.layer == 1000 })
        #expect(Set(windows.map { "\($0.bounds.size)" }) == Set(frames.map { "\($0)" }))
        let center = await MainActor.run { CGPoint(x: NSScreen.screens[0].frame.midX, y: NSScreen.screens[0].frame.midY) }
        let hit = await MainActor.run { WindowServer.windowNumberHit(at: center) }
        #expect(!windows.map(\.number).contains(hit), "a click must go through the confetti")
        let frontAfter = await MainActor.run { NSWorkspace.shared.frontmostApplication?.processIdentifier }
        #expect(frontBefore == frontAfter)
        let deadline = Date().addingTimeInterval(5)
        while kill(pid, 0) == 0, Date() < deadline { usleep(100_000) }
        #expect(kill(pid, 0) != 0, "confetti pid \(pid) is still alive 5 s after a 2 s show")
    }
}
