import Foundation

/// A key + modifier combination as stored in `com.apple.symbolichotkeys` (`CGEventFlags` raw value).
struct KeyCombo: Equatable {
    let keyCode: UInt16
    let flags: UInt64
}

/// Reads the system "Mission Control" shortcuts so switching follows whatever keys the user configured.
/// Structure verified in docs/phase0-findings.md.
enum SymbolicHotKeys {
    static let domain = "com.apple.symbolichotkeys"
    static let moveLeft = 79
    static let moveRight = 81
    private static let firstDesktop = 118  // "Switch to Desktop 1"; 16 in a row

    static func desktopID(_ index: Int) -> Int? {
        (1...16).contains(index) ? firstDesktop + index - 1 : nil
    }

    /// Enabled shortcuts keyed by symbolic hotkey ID. A missing entry means disabled
    /// (the plist only lists shortcuts the user has touched).
    static func parse(_ raw: [String: Any]) -> [Int: KeyCombo] {
        var result: [Int: KeyCombo] = [:]
        for (key, value) in raw {
            guard let id = Int(key),
                  let entry = value as? [String: Any],
                  (entry["enabled"] as? Bool) == true,
                  let params = (entry["value"] as? [String: Any])?["parameters"] as? [Int],
                  params.count == 3,
                  let keyCode = UInt16(exactly: params[1]),
                  let flags = UInt64(exactly: params[2]) else { continue }
            result[id] = KeyCombo(keyCode: keyCode, flags: flags)
        }
        return result
    }

    /// Re-read on every switch: the user may toggle shortcuts in System Settings while we run.
    static func load() -> [Int: KeyCombo] {
        CFPreferencesAppSynchronize(domain as CFString)
        let raw = CFPreferencesCopyAppValue("AppleSymbolicHotKeys" as CFString, domain as CFString)
        return parse(raw as? [String: Any] ?? [:])
    }
}
