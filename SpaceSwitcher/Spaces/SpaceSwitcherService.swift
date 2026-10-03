import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Switches desktops by synthesizing the system Mission Control shortcuts.
/// Requires Accessibility; without it macOS silently drops the events (docs/phase0-findings.md).
///
/// The Dock sometimes stops reacting to "Switch to Desktop N" while Ctrl+←/→ keep working, and the
/// unhandled Ctrl+N then leaks into the frontmost app (#22). So a direct switch is verified: if the
/// Space hasn't changed shortly after, the trip is finished with arrows and later switches skip the
/// direct shortcut until the Dock is restarted or a direct switch works again.
enum SpaceSwitcherService {
    /// macOS queues Ctrl+→ presses even while the slide animation runs: spike/arrows.swift
    /// saw no drops with 0s, 0.05s, 0.15s or 0.3s gaps. A small gap is kept as a margin.
    private static let arrowGap: TimeInterval = 0.05
    /// A working direct switch changes the active Space after ~0.3 s (measured in #8); wait a bit more.
    private static let directTimeout: TimeInterval = 0.7

    /// Posted on the main queue when `directShortcutsUnresponsive` changes.
    static let healthDidChange = Notification.Name("SpaceSwitcherService.healthDidChange")

    private static let lock = NSLock()
    private static var unresponsive = false

    /// True once the Dock ignored a "Switch to Desktop N" press (#22).
    static var directShortcutsUnresponsive: Bool {
        lock.lock(); defer { lock.unlock() }
        return unresponsive
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Debug-only test hook for #22: pretend the Dock swallowed the direct shortcut (nothing is sent),
    /// so the fallback and the notice can be exercised while the Dock is healthy.
    /// `defaults write io.github.unh6unh6.SpaceSwitcher debugSimulateDockIgnoresShortcuts -bool true`
    private static var simulateDockIgnoringShortcuts: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debugSimulateDockIgnoresShortcuts")
        #else
        return false
        #endif
    }

    @discardableResult
    static func switchTo(_ target: Space) -> SwitchPlan {
        guard isTrusted else { return .none }
        let snapshot = SpaceProvider.snapshot()
        let hotkeys = SymbolicHotKeys.load()
        let plan = SwitchPlanner.plan(to: target, currentPosition: snapshot.activePosition, hotkeys: hotkeys,
                                      avoidDirect: directShortcutsUnresponsive)
        // Off the main thread: arrow gaps and the direct-switch check both wait.
        DispatchQueue.global(qos: .userInteractive).async {
            switch plan {
            case .none:
                break
            case .direct(let combo):
                if !simulateDockIgnoringShortcuts { press(combo) }
                verifyDirect(targetPosition: target.position, hotkeys: hotkeys)
            case .arrows(let combo, let count):
                pressRepeatedly(combo, count: count)
            }
        }
        return plan
    }

    /// Clears the "unresponsive" state, e.g. after restarting the Dock.
    static func resetHealth() {
        setUnresponsive(false)
    }

    /// Restarts the Dock, which brings "Switch to Desktop N" back (verified 2026-10-03, #22).
    /// Windows and the desktop arrangement survive; the Dock just blinks for a second.
    static func restartDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
        task.waitUntilExit()
        resetHealth()
    }

    private static func verifyDirect(targetPosition: Int, hotkeys: [Int: KeyCombo]) {
        let deadline = Date().addingTimeInterval(directTimeout)
        while Date() < deadline {
            if SpaceProvider.snapshot().activePosition == targetPosition {
                setUnresponsive(false)
                return
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        let landed = SpaceProvider.snapshot().activePosition
        let followUp = SwitchPlanner.followUp(targetPosition: targetPosition, landedPosition: landed, hotkeys: hotkeys)
        guard case let .arrows(combo, count) = followUp else { return }
        setUnresponsive(true)
        pressRepeatedly(combo, count: count)
    }

    private static func setUnresponsive(_ value: Bool) {
        lock.lock()
        let changed = unresponsive != value
        unresponsive = value
        lock.unlock()
        if changed {
            DispatchQueue.main.async { NotificationCenter.default.post(name: healthDidChange, object: nil) }
        }
    }

    private static func pressRepeatedly(_ combo: KeyCombo, count: Int) {
        for i in 0..<count {
            if i > 0 { Thread.sleep(forTimeInterval: arrowGap) }
            press(combo)
        }
    }

    private static func press(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: down) else { continue }
            event.flags = CGEventFlags(rawValue: combo.flags)
            event.post(tap: .cghidEventTap)
        }
        // `before: 0` rather than the current state: that state may already contain a stuck Control from an
        // earlier synthesized press, and switches only happen once the user has let go of the shortcut anyway.
        for keyUp in ModifierRelease.keyUps(for: combo.flags, before: 0) {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyUp.keyCode, keyDown: false) else { continue }
            event.type = .flagsChanged
            event.flags = CGEventFlags(rawValue: keyUp.flagsAfter)
            event.post(tap: .cghidEventTap)
        }
    }
}
