import ApplicationServices
import CoreGraphics
import Foundation

/// Switches desktops by synthesizing the system Mission Control shortcuts.
/// Requires Accessibility; without it macOS silently drops the events (docs/phase0-findings.md).
enum SpaceSwitcherService {
    /// macOS queues Ctrl+→ presses even while the slide animation runs: spike/arrows.swift
    /// saw no drops with 0s, 0.05s, 0.15s or 0.3s gaps. A small gap is kept as a margin.
    private static let arrowGap: TimeInterval = 0.05

    static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    static func switchTo(_ target: Space) -> SwitchPlan {
        guard isTrusted else { return .none }
        let snapshot = SpaceProvider.snapshot()
        let plan = SwitchPlanner.plan(to: target, currentPosition: snapshot.activePosition,
                                      hotkeys: SymbolicHotKeys.load())
        switch plan {
        case .none:
            break
        case .direct(let combo):
            press(combo)
        case .arrows(let combo, let count):
            // Off the main thread so the menu/panel isn't blocked while the gaps elapse.
            DispatchQueue.global(qos: .userInteractive).async {
                for i in 0..<count {
                    if i > 0 { Thread.sleep(forTimeInterval: arrowGap) }
                    press(combo)
                }
            }
        }
        return plan
    }

    private static func press(_ combo: KeyCombo) {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: down) else { continue }
            event.flags = CGEventFlags(rawValue: combo.flags)
            event.post(tap: .cghidEventTap)
        }
    }
}
