import XCTest
@testable import SpaceSwitcher

final class SymbolicHotKeysTests: XCTestCase {
    private func entry(enabled: Bool, _ params: [Any]) -> [String: Any] {
        ["enabled": enabled, "value": ["type": "standard", "parameters": params]]
    }

    // Shapes copied from the real plist in docs/phase0-findings.md.
    func testParsesEnabledEntries() {
        let raw: [String: Any] = [
            "118": entry(enabled: true, [65535, 18, 262144]),
            "79": entry(enabled: true, [65535, 123, 8650752]),
        ]
        let keys = SymbolicHotKeys.parse(raw)
        XCTAssertEqual(keys[118], KeyCombo(keyCode: 18, flags: 262144))
        XCTAssertEqual(keys[79], KeyCombo(keyCode: 123, flags: 8650752))
    }

    func testSkipsDisabledEntries() {
        let keys = SymbolicHotKeys.parse(["119": entry(enabled: false, [65535, 19, 262144])])
        XCTAssertNil(keys[119])
    }

    func testSkipsMalformedEntries() {
        let raw: [String: Any] = [
            "120": entry(enabled: true, [65535, 20]),        // too few parameters
            "121": ["enabled": true],                        // no value
            "abc": entry(enabled: true, [65535, 21, 262144]), // non-numeric ID
            "122": "garbage",
        ]
        XCTAssertTrue(SymbolicHotKeys.parse(raw).isEmpty)
    }

    func testDesktopIDMapping() {
        XCTAssertEqual(SymbolicHotKeys.desktopID(1), 118)
        XCTAssertEqual(SymbolicHotKeys.desktopID(16), 133)
        XCTAssertNil(SymbolicHotKeys.desktopID(0))
        XCTAssertNil(SymbolicHotKeys.desktopID(17))
    }
}
