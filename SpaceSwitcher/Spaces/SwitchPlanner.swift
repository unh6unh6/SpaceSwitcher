import Foundation

enum SwitchPlan: Equatable {
    case none
    /// "Switch to Desktop N" shortcut.
    case direct(KeyCombo)
    /// Fallback: press Ctrl+←/→ `count` times. Slow because each step animates.
    case arrows(KeyCombo, count: Int)
}

/// Decides which keystrokes reach a desktop. Pure; the service only executes the plan.
enum SwitchPlanner {
    static func plan(to target: Space, currentPosition: Int?, hotkeys: [Int: KeyCombo]) -> SwitchPlan {
        if target.isCurrent || target.position == currentPosition { return .none }

        if let id = SymbolicHotKeys.desktopID(target.index), let combo = hotkeys[id] {
            return .direct(combo)
        }

        guard let current = currentPosition else { return .none }
        let delta = target.position - current
        let arrowID = delta > 0 ? SymbolicHotKeys.moveRight : SymbolicHotKeys.moveLeft
        guard let arrow = hotkeys[arrowID] else { return .none }
        return .arrows(arrow, count: abs(delta))
    }
}
