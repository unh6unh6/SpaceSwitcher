import CoreGraphics
import Foundation

/// Session-level CGEventTap for the global shortcut (SPEC §2.3). Carbon hotkeys can't do Option-only
/// combos on macOS 15+ and can't see the modifier being released, which cycle mode needs.
///
/// The tap lives on the main run loop so the callback can consult the state machine synchronously
/// to decide whether to swallow a key; anything heavier is dispatched async by the handler.
final class EventTap {
    struct KeyEvent {
        let keyCode: UInt16
        let flags: UInt64
        let isAutorepeat: Bool
    }

    /// Return true to swallow the key.
    var onKeyDown: ((KeyEvent) -> Bool)?
    /// Called with (previous flags, current flags).
    var onFlagsChanged: ((UInt64, UInt64) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
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
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// The system disables slow or stale taps (timeouts, sleep/wake); turn it back on.
    func ensureEnabled() {
        if let tap, !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
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
