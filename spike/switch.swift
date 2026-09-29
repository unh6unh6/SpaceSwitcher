// Phase 0 spike: synthesize the "Switch to Desktop N" shortcut read from com.apple.symbolichotkeys.
// Run: swift spike/switch.swift <N>   (needs Accessibility for the terminal app)
import Foundation
import CoreGraphics
import ApplicationServices

typealias CGSConnectionID = Int32
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID
@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> Int

// "left"/"right" exercise the Ctrl+←/→ fallback (IDs 79/81); a number uses IDs 118+.
let arg = CommandLine.arguments.dropFirst().first ?? "2"
let hotkeyID = arg == "left" ? 79 : arg == "right" ? 81 : 117 + (Int(arg) ?? 2)
print("AXIsProcessTrusted:", AXIsProcessTrusted())

let hotkeys = UserDefaults(suiteName: "com.apple.symbolichotkeys")?
    .dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
guard let entry = hotkeys[String(hotkeyID)] as? [String: Any],
      (entry["enabled"] as? Bool) == true,
      let params = (entry["value"] as? [String: Any])?["parameters"] as? [Int],
      params.count == 3 else {
    print("hotkey \(hotkeyID) missing or disabled"); exit(1)
}
let keyCode = CGKeyCode(params[1])
let flags = CGEventFlags(rawValue: UInt64(params[2]))
print("hotkey \(hotkeyID): keyCode=\(keyCode) flags=0x\(String(flags.rawValue, radix: 16))")

let cid = CGSMainConnectionID()
print("active before:", CGSGetActiveSpace(cid))
let src = CGEventSource(stateID: .hidSystemState)
for down in [true, false] {
    let e = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: down)!
    e.flags = flags
    e.post(tap: .cghidEventTap)
}
Thread.sleep(forTimeInterval: 1.0)
print("active after:", CGSGetActiveSpace(cid))
