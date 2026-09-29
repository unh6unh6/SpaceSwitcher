import CoreGraphics

/// The switcher shortcut: one key plus one or more modifiers (`CGEventFlags` raw bits).
/// Hardcoded to Option+E until the recorder arrives in Phase 5.
struct Shortcut: Equatable, Codable {
    let keyCode: UInt16
    let modifiers: UInt64

    static let `default` = Shortcut(keyCode: KeyCode.e, modifiers: CGEventFlags.maskAlternate.rawValue)
}

/// Virtual key codes (ANSI layout positions, independent of the input language).
enum KeyCode {
    static let e: UInt16 = 14
    static let r: UInt16 = 15
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
    /// Top-row 1…9.
    static let digits: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
}
