// Phase 2 spike: how far apart must repeated Ctrl+→ presses be so none get dropped?
// Run: swift spike/arrows.swift   (starts from desktop 1 via Ctrl+1; needs >= 3 desktops)
import Foundation
import CoreGraphics

@_silgen_name("CGSMainConnectionID") func CGSMainConnectionID() -> Int32
@_silgen_name("CGSGetActiveSpace") func CGSGetActiveSpace(_ cid: Int32) -> Int
@_silgen_name("CGSCopyManagedDisplaySpaces") func CGSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray

let cid = CGSMainConnectionID()
func position() -> Int {
    let d = (CGSCopyManagedDisplaySpaces(cid) as! [[String: Any]])[0]["Spaces"] as! [[String: Any]]
    return d.firstIndex { ($0["ManagedSpaceID"] as? Int) == CGSGetActiveSpace(cid) } ?? -1
}
func press(_ key: CGKeyCode, _ flags: UInt64) {
    for down in [true, false] {
        let e = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)!
        e.flags = CGEventFlags(rawValue: flags)
        e.post(tap: .cghidEventTap)
    }
}
for gap in [0.0, 0.05, 0.15, 0.3] {
    press(18, 0x40000)                  // Ctrl+1
    Thread.sleep(forTimeInterval: 1.2)
    let start = position()
    let t0 = Date()
    for i in 0..<2 { if i > 0 { Thread.sleep(forTimeInterval: gap) }; press(124, 0x840000) }
    var end = position()
    while end != start + 2 && Date().timeIntervalSince(t0) < 3 { Thread.sleep(forTimeInterval: 0.02); end = position() }
    print(String(format: "gap %.2fs: position %d -> %d (%@) settled in %.2fs",
                 gap, start, end, end == start + 2 ? "OK" : "DROPPED", Date().timeIntervalSince(t0)))
    Thread.sleep(forTimeInterval: 1.0)
}
press(18, 0x40000)
