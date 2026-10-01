import CoreGraphics
import Foundation
import os

/// Session-level CGEventTap for the global shortcut (SPEC §2.3). Carbon hotkeys can't do Option-only
/// combos on macOS 15+ and can't see the modifier being released, which cycle mode needs.
///
/// The tap runs on its **own thread's run loop**, not the main one (#10): when the main thread stalled
/// (measured once at ~13 s), the tap callback couldn't run, macOS bypassed the tap, and Option+E typed ´.
/// Callbacks (`onKeyDown`, `onFlagsChanged`) run on the tap thread; use `perform` to run other work there.
final class EventTap {
    struct KeyEvent {
        let keyCode: UInt16
        let flags: UInt64
        let isAutorepeat: Bool
    }

    /// Return true to swallow the key. Called on the tap thread.
    var onKeyDown: ((KeyEvent) -> Bool)?
    /// Called on the tap thread with (previous flags, current flags).
    var onFlagsChanged: ((UInt64, UInt64) -> Void)?

    private static let log = Logger(subsystem: "io.github.unh6unh6.SpaceSwitcher", category: "EventTap")
    /// Callbacks slower than this get logged; macOS starts disabling taps at around 1 s.
    private static let slowCallback: TimeInterval = 0.2

    private var tap: CFMachPort?
    private var runLoop: CFRunLoop?
    private var lastFlags: UInt64 = 0

    var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    /// Fails without Accessibility permission; call again once it's granted.
    @discardableResult
    func start() -> Bool {
        if tap != nil { ensureEnabled(); return true }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                          eventsOfInterest: mask, callback: eventTapCallback,
                                          userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [weak self] in
            self?.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()
            CFRunLoopRun()
        }
        thread.name = "SpaceSwitcher.EventTap"
        thread.qualityOfService = .userInteractive
        thread.start()
        ready.wait()
        return true
    }

    /// Runs `block` on the tap thread, serialized with the key callbacks. Runs inline before `start()`.
    func perform(_ block: @escaping () -> Void) {
        guard let runLoop else { block(); return }
        CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes.rawValue, block)
        CFRunLoopWakeUp(runLoop)
    }

    /// The system disables slow or stale taps (timeouts, sleep/wake); turn it back on.
    func ensureEnabled() {
        if let tap, !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let started = Date()
        defer {
            let elapsed = Date().timeIntervalSince(started)
            if elapsed > Self.slowCallback {
                Self.log.error("slow tap callback: \(Int(elapsed * 1000), privacy: .public) ms (type \(type.rawValue, privacy: .public))")
            }
        }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            Self.log.error("tap disabled by system (type \(type.rawValue, privacy: .public)); re-enabling")
            ensureEnabled()
        case .keyDown:
            let key = KeyEvent(keyCode: UInt16(event.getIntegerValueField(.keyboardEventKeycode)),
                               flags: event.flags.rawValue,
                               isAutorepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0)
            if onKeyDown?(key) == true { return nil }
        case .flagsChanged:
            let flags = event.flags.rawValue
            onFlagsChanged?(lastFlags, flags)
            lastFlags = flags
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }
}

private func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
                              userInfo: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    return Unmanaged<EventTap>.fromOpaque(userInfo).takeUnretainedValue().handle(type, event)
}
