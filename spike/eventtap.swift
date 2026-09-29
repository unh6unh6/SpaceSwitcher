// Phase 0 spike: can a session CGEventTap swallow Option+E and see Option being released?
// Run: swift spike/eventtap.swift [seconds]   (needs Accessibility for the terminal app)
import Foundation
import CoreGraphics
import ApplicationServices

let seconds = Double(CommandLine.arguments.dropFirst().first ?? "20") ?? 20
let kVK_ANSI_E: Int64 = 14
print("AXIsProcessTrusted:", AXIsProcessTrusted())

func stamp() -> String { String(format: "%.3f", Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1000)) }

var tapRef: CFMachPort?
let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
let callback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        print(stamp(), "tap disabled (\(type.rawValue)) -> re-enabling")
        if let t = tapRef { CGEvent.tapEnable(tap: t, enable: true) }
    case .keyDown:
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        let opt = event.flags.contains(.maskAlternate)
        let shift = event.flags.contains(.maskShift)
        if code == kVK_ANSI_E && opt {
            print(stamp(), "Option\(shift ? "+Shift" : "")+E  -> CONSUMED")
            return nil
        }
    case .flagsChanged:
        print(stamp(), "flagsChanged option=\(event.flags.contains(.maskAlternate))")
    default: break
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                  options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                                  callback: callback, userInfo: nil) else {
    print("tapCreate FAILED (permission?)"); exit(1)
}
tapRef = tap
let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)
print("tap active for \(Int(seconds))s — type Option+E in a text field, then release Option")
setvbuf(stdout, nil, _IOLBF, 0)
CFRunLoopRunInMode(.defaultMode, seconds, false)
print("done")
