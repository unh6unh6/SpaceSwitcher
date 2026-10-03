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
    /// - Parameter avoidDirect: the Dock is ignoring "Switch to Desktop N" (#22), so go straight to arrows.
    static func plan(to target: Space, currentPosition: Int?, hotkeys: [Int: KeyCombo],
                     avoidDirect: Bool = false) -> SwitchPlan {
        if target.isCurrent || target.position == currentPosition { return .none }

        if !avoidDirect, let id = SymbolicHotKeys.desktopID(target.index), let combo = hotkeys[id] {
            return .direct(combo)
        }
        return arrows(from: currentPosition, to: target.position, hotkeys: hotkeys)
    }

    /// What to do once a direct shortcut had its chance (#22): nothing if we arrived, otherwise finish the
    /// trip with Ctrl+←/→ from wherever we are now.
    static func followUp(targetPosition: Int, landedPosition: Int?, hotkeys: [Int: KeyCombo]) -> SwitchPlan {
        landedPosition == targetPosition ? .none : arrows(from: landedPosition, to: targetPosition, hotkeys: hotkeys)
    }

    private static func arrows(from current: Int?, to target: Int, hotkeys: [Int: KeyCombo]) -> SwitchPlan {
        guard let current, current != target else { return .none }
        let delta = target - current
        let arrowID = delta > 0 ? SymbolicHotKeys.moveRight : SymbolicHotKeys.moveLeft
        guard let arrow = hotkeys[arrowID] else { return .none }
        return .arrows(arrow, count: abs(delta))
    }
}
