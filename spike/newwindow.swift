// #16 spike: apply the "new window" ladder to an app and check the window lands on the current desktop
// without macOS jumping to another Space.
// Run: swift spike/newwindow.swift <bundle-id> [--close]   (terminal needs Accessibility)
import AppKit
import ApplicationServices

@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetActiveSpace") func CGSGetActiveSpace(_ cid: Int32) -> Int
@_silgen_name("CGSCopySpacesForWindows") func CGSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ wids: CFArray) -> CFArray
typealias GetWindow = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
let axGetWindow = unsafeBitCast(dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow")!, to: GetWindow.self)

let cid = CGSMainConnectionID()
func attr(_ e: AXUIElement, _ n: String) -> AnyObject? { var v: AnyObject?; return AXUIElementCopyAttributeValue(e, n as CFString, &v) == .success ? v : nil }
func kids(_ e: AXUIElement) -> [AXUIElement] { attr(e, kAXChildrenAttribute) as? [AXUIElement] ?? [] }

/// Document windows of `pid` (layer 0, not tiny) → set of Space IDs each is on.
func windows(of pid: pid_t) -> [Int: [Int]] {
    let all = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
    var result: [Int: [Int]] = [:]
    for w in all where (w[kCGWindowOwnerPID as String] as? pid_t) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
        let b = w[kCGWindowBounds as String] as! [String: Double]
        guard (b["Width"] ?? 0) >= 50, (b["Height"] ?? 0) >= 50, let id = w[kCGWindowNumber as String] as? Int else { continue }
        let spaces = CGSCopySpacesForWindows(cid, 7, [id] as CFArray) as? [Int] ?? []
        if !spaces.isEmpty { result[id] = spaces }   // hidden helper windows (TextEdit has several) belong to no Space
    }
    return result
}

/// Ladder step 3: the menu item to press. Window-titled "New…" first; ⌘N only for document apps.
func newWindowItem(_ app: NSRunningApplication, isDocumentApp: Bool) -> (AXUIElement, String)? {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    guard let bar = attr(ax, kAXMenuBarAttribute) else { return nil }
    let windowWords = ["window", "윈도우", "창", "ウインドウ", "窗口", "fenster", "fenêtre", "ventana"]
    let newWords = ["new", "새", "신규", "新規", "新しい", "新建", "neu", "nouv", "nuev"]
    var cmdN: (AXUIElement, String)?
    for (index, top) in kids(bar as! AXUIElement).enumerated() where index > 0 { for menu in kids(top) { for item in kids(menu) {
        let title = attr(item, kAXTitleAttribute) as? String ?? ""
        let lower = title.lowercased()
        // Explicit "new window": title says so AND its shortcut key is N (⌘N, Notion ⌘⇧N). The key check drops
        // look-alikes such as TextEdit "새로운 윈도우로 탭 이동" or Finder "새로운 윈도우에서 열기 및 닫기".
        let key = (attr(item, "AXMenuItemCmdChar") as? String)?.lowercased()
        if key == "n", newWords.contains(where: { lower.hasPrefix($0) }), windowWords.contains(where: { lower.contains($0) }) {
            return (item, title)
        }
        // ⌘N candidate only in the File menu (index 2): IntelliJ's ⌘N is "Generate…" under Code.
        // Still only a candidate: Claude's File-menu ⌘N is "새 채팅" — confirmed by the user in the real feature.
        if cmdN == nil, index == 2, (attr(item, "AXMenuItemCmdChar") as? String)?.lowercased() == "n",
           (attr(item, "AXMenuItemCmdModifiers") as? Int) == 0 { cmdN = (item, title) }
    } } }
    return isDocumentApp ? cmdN : nil
}

if CommandLine.arguments[1] == "--classify" {
    for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
        let url = app.bundleURL
        let docs = (url.flatMap { Bundle(url: $0)?.infoDictionary?["CFBundleDocumentTypes"] } as? [[String: Any]]) ?? []
        let isDoc = docs.contains { ($0["CFBundleTypeRole"] as? String) == "Editor" }
        let explicit = newWindowItem(app, isDocumentApp: false).map { "확실: '\($0.1)'" }
        let candidate = explicit == nil ? newWindowItem(app, isDocumentApp: true).map { "후보(확인 필요): '\($0.1)'" } : nil
        print(String(format: "%-16@", (app.localizedName ?? "?") as NSString), "→", explicit ?? candidate ?? "단일 창 앱")
    }
    exit(0)
}
let bundleID = CommandLine.arguments[1]
let shouldClose = CommandLine.arguments.contains("--close")
guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { print("not installed"); exit(1) }
let docTypes = (Bundle(url: appURL)?.infoDictionary?["CFBundleDocumentTypes"] as? [[String: Any]]) ?? []
let isDocumentApp = docTypes.contains { ($0["CFBundleTypeRole"] as? String) == "Editor" }

let startSpace = CGSGetActiveSpace(cid)
let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
let before = running.map { windows(of: $0.processIdentifier) } ?? [:]
var step: String

func launch() {
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    let done = DispatchSemaphore(value: 0)
    NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in done.signal() }
    done.wait()
}

if running == nil {
    step = "1 실행"; launch()
} else if before.isEmpty {
    step = "2 다시 열기(reopen)"; launch()   // opening a running app sends kAEReopenApplication
} else if let (item, title) = newWindowItem(running!, isDocumentApp: isDocumentApp) {
    step = "3 메뉴 '\(title)'"
    let err = AXUIElementPerformAction(item, kAXPressAction as CFString)
    if err != .success { print("AXPress 실패", err.rawValue) }
    Thread.sleep(forTimeInterval: 0.3)
    running!.activate()
} else {
    step = "4 단일 창 앱 → 건너뜀"
}

// Wait up to 8 s for a new window, watching for a Space jump.
var newWindow: (Int, [Int])?, jumped = false
let t0 = Date()
while Date().timeIntervalSince(t0) < (running == nil ? 30 : 8), newWindow == nil {
    Thread.sleep(forTimeInterval: 0.2)
    if CGSGetActiveSpace(cid) != startSpace { jumped = true }
    if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
        newWindow = windows(of: app.processIdentifier).first { before[$0.key] == nil }.map { ($0.key, $0.value) }
    }
}
let elapsed = Date().timeIntervalSince(t0)
let onCurrent = newWindow.map { $0.1.contains(startSpace) } ?? false
print("앱: \(bundleID) | 문서앱: \(isDocumentApp) | 시도: \(step)")
print(String(format: "  새 창: %@ | 현재 데스크탑에: %@ | 화면 이동: %@ | %.1fs",
             newWindow == nil ? "없음" : "있음", onCurrent ? "예" : "아니오",
             jumped || CGSGetActiveSpace(cid) != startSpace ? "있음" : "없음", elapsed))

// Close only the window this run created.
if shouldClose, let (wid, _) = newWindow, let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
    let ax = AXUIElementCreateApplication(app.processIdentifier)
    for w in attr(ax, kAXWindowsAttribute) as? [AXUIElement] ?? [] {
        var id: CGWindowID = 0
        if axGetWindow(w, &id) == .success, Int(id) == wid, let close = attr(w, kAXCloseButtonAttribute) {
            AXUIElementPerformAction(close as! AXUIElement, kAXPressAction as CFString); print("  만든 창 닫음")
        }
    }
}
