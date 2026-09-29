import CoreGraphics

/// Posting a keyDown whose flags include Control leaves Control "held" in the system modifier state
/// indefinitely (measured: still set 3 s later, whatever the event source). The next real Option+E then
/// arrives as Ctrl+Option+E, misses the shortcut and beeps. Posting a modifier key-up afterwards clears it.
enum ModifierRelease {
    struct KeyUp: Equatable {
        let keyCode: UInt16
        /// Flags carried by this flagsChanged event, i.e. what is still held after it.
        let flagsAfter: UInt64
    }

    private static let modifierKeys: [(flag: UInt64, keyCode: UInt16)] = [
        (CGEventFlags.maskControl.rawValue, 59),
        (CGEventFlags.maskAlternate.rawValue, 58),
        (CGEventFlags.maskShift.rawValue, 56),
        (CGEventFlags.maskCommand.rawValue, 55),
        (CGEventFlags.maskSecondaryFn.rawValue, 63),
    ]

    /// Key-ups that undo the modifiers in `flags` which were not already down in `before`.
    static func keyUps(for flags: UInt64, before: UInt64) -> [KeyUp] {
        var held = before | flags
        var result: [KeyUp] = []
        for (flag, keyCode) in modifierKeys where flags & flag != 0 && before & flag == 0 {
            held &= ~flag
            result.append(KeyUp(keyCode: keyCode, flagsAfter: held & allModifiers))
        }
        return result
    }

    private static let allModifiers = modifierKeys.reduce(UInt64(0)) { $0 | $1.flag }
}
