import AppKit
import BigArrowCore

/// Resolves `--window "App[:title]"` without any permission: the app's pid via NSWorkspace,
/// then that pid's windows via CGWindowList. Owner and window names are not used for the app
/// match because macOS 26 hides them without Screen Recording.
/// https://developer.apple.com/forums/thread/839069
@MainActor
public enum WindowTarget {
    public static func resolve(_ query: WindowQuery, anchor: WindowAnchor, screens: ScreenSpace) throws -> ResolvedTarget {
        let (window, detail) = try find(query, screens: screens)
        var described = detail
        described["anchor"] = anchor.rawValue
        let point = anchor.point(in: WindowMatcher.visiblePart(of: window, on: screens.displays))
        return ResolvedTarget(shape: .point(point), source: "window", detail: described)
    }

    /// The visible part of the app's front window (a card sits beside it).
    public static func frame(_ query: WindowQuery, screens: ScreenSpace) throws -> CGRect {
        WindowMatcher.visiblePart(of: try find(query, screens: screens).window, on: screens.displays)
    }

    static func find(_ query: WindowQuery, screens: ScreenSpace) throws -> (window: WindowInfo, detail: [String: String]) {
        let apps = runningApps()
        let windows = onScreenWindows()
        let matchedApps = WindowMatcher.apps(matching: query.app, in: apps)
        guard !matchedApps.isEmpty else {
            let names = WindowMatcher.appsWithWindows(apps, windows).joined(separator: ", ")
            throw BigArrowError.unresolvable("no running app matches '\(query.app)'; apps with windows: \(names)")
        }
        if query.title != nil {
            try Permission.screenRecording.require(for: "Matching a window by title")
        }
        let found = WindowMatcher.windows(of: matchedApps.map(\.pid), in: windows, title: query.title, displays: screens.displays)
        let appName = matchedApps[0].name ?? query.app
        guard let window = found.first else {
            let what = query.title.map { "no window titled '*\($0)*'" } ?? "no visible window"
            throw BigArrowError.unresolvable("\(appName) has \(what) on screen")
        }
        var detail = ["app": appName, "windowCount": String(found.count)]
        detail["title"] = window.title
        return (window, detail)
    }

    /// Every running app with its pid, name and bundle id.
    public static func runningApps() -> [RunningAppInfo] {
        NSWorkspace.shared.runningApplications.map {
            RunningAppInfo(pid: $0.processIdentifier, name: $0.localizedName, bundleID: $0.bundleIdentifier)
        }
    }

    public static func onScreenWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap(windowInfo)
    }

    static func windowInfo(_ entry: [String: Any]) -> WindowInfo? {
        guard let pid = entry[kCGWindowOwnerPID as String] as? Int32,
              let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { return nil }
        return WindowInfo(
            ownerPID: pid,
            layer: entry[kCGWindowLayer as String] as? Int ?? 0,
            bounds: bounds,
            alpha: entry[kCGWindowAlpha as String] as? Double ?? 1,
            title: entry[kCGWindowName as String] as? String
        )
    }
}
