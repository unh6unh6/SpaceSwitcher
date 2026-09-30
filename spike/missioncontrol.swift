// v0.2.0 spike (#1, #9): open Mission Control and dump the Dock's accessibility tree around the
// Spaces bar, to find the "add desktop" button and a per-desktop "remove" action.
// Run: swift spike/missioncontrol.swift   (terminal needs Accessibility; Mission Control opens ~2 s)
import AppKit
import ApplicationServices

func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(e, name as CFString, &value) == .success ? value : nil
}
func actions(_ e: AXUIElement) -> [String] {
    var names: CFArray?
    return AXUIElementCopyActionNames(e, &names) == .success ? (names as? [String] ?? []) : []
}
func dump(_ e: AXUIElement, depth: Int, maxDepth: Int) {
    let role = attr(e, kAXRoleAttribute) as? String ?? "?"
    let sub = attr(e, kAXSubroleAttribute) as? String
    let title = attr(e, kAXTitleAttribute) as? String
    let desc = attr(e, kAXDescriptionAttribute) as? String
    let ident = attr(e, "AXIdentifier") as? String
    var line = String(repeating: "  ", count: depth) + role
    if let sub { line += " [\(sub)]" }
    if let title, !title.isEmpty { line += " title=\"\(title)\"" }
    if let desc, !desc.isEmpty { line += " desc=\"\(desc)\"" }
    if let ident { line += " id=\(ident)" }
    let acts = actions(e).filter { $0 != "AXShowMenu" && $0 != "AXScrollToVisible" }
    if !acts.isEmpty { line += " actions=\(acts)" }
    print(line)
    guard depth < maxDepth, let children = attr(e, kAXChildrenAttribute) as? [AXUIElement] else { return }
    for child in children { dump(child, depth: depth + 1, maxDepth: maxDepth) }
}

guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
    print("Dock not running"); exit(1)
}
print("AXIsProcessTrusted:", AXIsProcessTrusted())
let dockAX = AXUIElementCreateApplication(dock.processIdentifier)

NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
// Mission Control builds its AX subtree a moment after it appears; poll for it.
func missionControlGroup() -> AXUIElement? {
    (attr(dockAX, kAXChildrenAttribute) as? [AXUIElement])?.first { attr($0, "AXIdentifier") as? String == "mc" }
}
var mc: AXUIElement?
for _ in 0..<40 {
    Thread.sleep(forTimeInterval: 0.1)
    if let group = missionControlGroup(), let kids = attr(group, kAXChildrenAttribute) as? [AXUIElement], !kids.isEmpty {
        mc = group; break
    }
}
print("=== Mission Control AX subtree ===")
if let mc { dump(mc, depth: 0, maxDepth: 8) } else { print("mc group has no children after 4 s") }

// Close Mission Control again.
NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
