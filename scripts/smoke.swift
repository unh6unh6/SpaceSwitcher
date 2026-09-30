// Smoke test for a running SpaceSwitcher: synthesizes the shortcut and checks that the panel
// appears, stays open after the modifier is released (Sticky), and closes on Esc.
//
//   swift scripts/smoke.swift            # default shortcut Option+E
//
// The terminal app running this needs Accessibility (System Settings → Privacy & Security),
// otherwise the synthesized keys are silently dropped. Prints PASS/FAIL per step; exit 1 on failure.
import CoreGraphics
import Foundation

let optionKeyCode: CGKeyCode = 58
let eKeyCode: CGKeyCode = 14
let escapeKeyCode: CGKeyCode = 53

func press(_ key: CGKeyCode, _ flags: CGEventFlags) {
    for down in [true, false] {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)!
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

func releaseModifiers() {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: optionKeyCode, keyDown: false)!
    event.type = .flagsChanged
    event.flags = []
    event.post(tap: .cghidEventTap)
}

/// The panel is SpaceSwitcher's only window above normal level (it uses .popUpMenu).
func panelVisible() -> Bool {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return windows.contains {
        ($0[kCGWindowOwnerName as String] as? String) == "SpaceSwitcher"
            && ($0[kCGWindowLayer as String] as? Int ?? 0) > 20
    }
}

func waitFor(_ expected: Bool, timeout: TimeInterval = 1) -> TimeInterval? {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if panelVisible() == expected { return Date().timeIntervalSince(start) }
        usleep(5_000)
    }
    return nil
}

var failed = false
func check(_ name: String, _ ok: Bool, _ detail: String = "") {
    print(ok ? "PASS" : "FAIL", name, detail)
    if !ok { failed = true }
}

check("SpaceSwitcher is running", !runningPIDs().isEmpty, "(open the app first)")
check("panel starts hidden", !panelVisible())

press(eKeyCode, .maskAlternate)
let shown = waitFor(true)
check("Option+E shows panel", shown != nil, shown.map { String(format: "(%.0f ms, target < 100)", $0 * 1000) } ?? "")

releaseModifiers()
usleep(200_000)
check("panel stays open after releasing Option (Sticky)", panelVisible())

press(escapeKeyCode, [])
check("Esc closes panel", waitFor(false) != nil)

exit(failed ? 1 : 0)

func runningPIDs() -> [pid_t] {
    let pipe = Pipe()
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    task.arguments = ["-x", "SpaceSwitcher"]
    task.standardOutput = pipe
    try? task.run()
    task.waitUntilExit()
    let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return out.split(separator: "\n").compactMap { pid_t($0) }
}
