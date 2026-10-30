// Accessibility helper for the System Settings guide shots (needs Accessibility for the terminal).
//   settings-ax value <identifier>     prints 0 or 1, the state of a switch such as python3.14_Toggle
//   settings-ax press <identifier>     presses that switch once
//   settings-ax reveal <label prefix>  scrolls the first element whose label starts so into view
//   settings-ax sidebar-end            scrolls the sidebar to its end (its first row is the account)
import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

/// An attribute that holds another element (parent, scroll bar), or nil.
func elementAttribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return unsafeBitCast(value, to: AXUIElement.self)
}

/// An attribute that holds an AXValue (position, size), or nil.
func valueAttribute(_ element: AXUIElement, _ name: String) -> AXValue? {
    guard let value = attribute(element, name), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    return unsafeBitCast(value, to: AXValue.self)
}

func label(_ element: AXUIElement) -> String {
    [kAXTitleAttribute, kAXDescriptionAttribute].compactMap { attribute(element, $0) as? String }.first { !$0.isEmpty } ?? ""
}

func first(in element: AXUIElement, depth: Int = 0, where test: (AXUIElement) -> Bool) -> AXUIElement? {
    if test(element) { return element }
    guard depth < 40 else { return nil }
    for child in (attribute(element, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
        if let found = first(in: child, depth: depth + 1, where: test) { return found }
    }
    return nil
}

func frame(_ element: AXUIElement) -> CGRect {
    var origin = CGPoint.zero, size = CGSize.zero
    if let value = valueAttribute(element, kAXPositionAttribute) { AXValueGetValue(value, .cgPoint, &origin) }
    if let value = valueAttribute(element, kAXSizeAttribute) { AXValueGetValue(value, .cgSize, &size) }
    return CGRect(origin: origin, size: size)
}

/// Steps the enclosing scroll area's scroll bar down until the element is fully visible.
func reveal(_ element: AXUIElement) {
    var area: AXUIElement? = element
    while let current = area, attribute(current, kAXRoleAttribute) as? String != "AXScrollArea" {
        area = elementAttribute(current, kAXParentAttribute)
    }
    guard let area, let bar = elementAttribute(area, kAXVerticalScrollBarAttribute) else { fail("no scroll area around the element") }
    for step in 0...40 {
        if frame(area).contains(frame(element)) { return }
        AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: Double(step) / 40))
        Thread.sleep(forTimeInterval: 0.05)
    }
    fail("could not scroll the element into view")
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("settings-ax: \(message)\n".utf8))
    exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2 else { fail("usage: settings-ax value|press <identifier> | reveal <label> | sidebar-end") }
guard let settings = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.systempreferences").first else {
    fail("System Settings is not running")
}
let app = AXUIElementCreateApplication(settings.processIdentifier)
guard let window = ((attribute(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []).first(where: {
    attribute($0, kAXMainAttribute) as? Bool == true
}) else { fail("no System Settings window") }

switch (arguments[1], arguments.count > 2 ? arguments[2] : "") {
case ("value", let identifier), ("press", let identifier):
    guard let control = first(in: window, where: { attribute($0, kAXIdentifierAttribute) as? String == identifier }) else {
        fail("no element with identifier \(identifier)")
    }
    if arguments[1] == "press" {
        AXUIElementPerformAction(control, kAXPressAction as CFString)
    } else {
        print((attribute(control, kAXValueAttribute) as? NSNumber)?.intValue ?? -1)
    }
case ("reveal", let prefix):
    guard let target = first(in: window, where: { attribute($0, kAXRoleAttribute) as? String == "AXButton" && label($0).hasPrefix(prefix) })
    else { fail("no button labelled \(prefix)") }
    reveal(target)
case ("sidebar-end", _):
    guard let sidebar = first(in: window, where: { attribute($0, kAXDescriptionAttribute) as? String == "Sidebar" }),
          let scrollArea = elementAttribute(sidebar, kAXParentAttribute),
          let bar = elementAttribute(scrollArea, kAXVerticalScrollBarAttribute) else { fail("no sidebar scroll bar") }
    AXUIElementSetAttributeValue(bar, kAXValueAttribute as CFString, NSNumber(value: 1.0))
default:
    fail("unknown command \(arguments[1])")
}
