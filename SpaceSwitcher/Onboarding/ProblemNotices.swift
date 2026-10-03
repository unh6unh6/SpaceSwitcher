import Foundation

/// The problems the menu bar can warn about (#23).
struct ProblemState: Equatable {
    var accessibilityMissing = false
    /// Desktop numbers whose "Switch to Desktop N" shortcut is off (slow arrow fallback).
    var desktopsWithoutShortcut: [Int] = []
    /// The Dock ignores "Switch to Desktop N" (#22).
    var dockIgnoresShortcuts = false
}

/// Decides which problem balloons to pop from the menu bar. A balloon appears when a problem *starts*,
/// not on every check while it lasts. Pure.
enum ProblemNotices {
    enum Notice: Equatable {
        case accessibility
        case dock
        case shortcutsOff([Int])
    }

    /// New balloons, most important first (the menu bar shows the first).
    static func new(previous: ProblemState, current: ProblemState, shortcutsMuted: Bool) -> [Notice] {
        var notices: [Notice] = []
        if current.accessibilityMissing && !previous.accessibilityMissing { notices.append(.accessibility) }
        if current.dockIgnoresShortcuts && !previous.dockIgnoresShortcuts { notices.append(.dock) }
        let newlyOff = Set(current.desktopsWithoutShortcut).subtracting(previous.desktopsWithoutShortcut)
        if !shortcutsMuted && !newlyOff.isEmpty { notices.append(.shortcutsOff(current.desktopsWithoutShortcut)) }
        return notices
    }

    /// Whether the menu bar title should carry the warning mark while problems last.
    static func needsWarningMark(_ state: ProblemState, shortcutsMuted: Bool) -> Bool {
        state.accessibilityMissing || state.dockIgnoresShortcuts
            || (!shortcutsMuted && !state.desktopsWithoutShortcut.isEmpty)
    }

    // MARK: "다시 보지 않기" for the shortcuts-off balloon

    private static let mutedKey = "muteShortcutsOffNotice"

    static func shortcutsMuted(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: mutedKey)
    }

    static func setShortcutsMuted(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: mutedKey)
    }
}
