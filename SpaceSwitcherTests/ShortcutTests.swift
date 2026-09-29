import CoreGraphics
import XCTest
@testable import SpaceSwitcher

final class ShortcutTests: XCTestCase {
    private let opt = CGEventFlags.maskAlternate.rawValue
    private let ctrl = CGEventFlags.maskControl.rawValue
    private let shift = CGEventFlags.maskShift.rawValue
    private let cmd = CGEventFlags.maskCommand.rawValue
    private let space: UInt16 = 49

    private var defaults: UserDefaults!
    private let suite = "SpaceSwitcherTests.Shortcut"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: validation (SPEC §3.6: one or more modifiers + one normal key)

    func testValidShortcuts() {
        XCTAssertNil(Shortcut.default.problem)
        XCTAssertNil(Shortcut(keyCode: space, modifiers: ctrl | opt).problem)
        XCTAssertNil(Shortcut(keyCode: KeyCode.e, modifiers: cmd | shift).problem)
    }

    func testNeedsARealModifier() {
        XCTAssertEqual(Shortcut(keyCode: KeyCode.e, modifiers: 0).problem, .needsModifier)
        // Shift alone would swallow capital letters while typing.
        XCTAssertEqual(Shortcut(keyCode: KeyCode.e, modifiers: shift).problem, .needsModifier)
    }

    func testModifierKeyAloneIsNotAKey() {
        XCTAssertEqual(Shortcut(keyCode: 58 /* Option */, modifiers: opt).problem, .modifierOnly)
        XCTAssertEqual(Shortcut(keyCode: 63 /* Fn */, modifiers: ctrl).problem, .modifierOnly)
    }

    // These keys drive the open panel (KeyMapper); as the shortcut key they would be shadowed.
    func testPanelKeysAreReserved() {
        for key in [KeyCode.escape, KeyCode.returnKey, KeyCode.keypadEnter, KeyCode.upArrow,
                    KeyCode.downArrow, KeyCode.r] + KeyCode.digits {
            XCTAssertEqual(Shortcut(keyCode: key, modifiers: opt).problem, .reservedKey, "key \(key)")
        }
    }

    // MARK: persistence

    func testStoredDefaultsToOptionE() {
        XCTAssertEqual(Shortcut.stored(in: defaults), .default)
    }

    func testStoreRoundTrip() {
        let custom = Shortcut(keyCode: space, modifiers: ctrl | opt)
        custom.store(in: defaults)
        XCTAssertEqual(Shortcut.stored(in: defaults), custom)
    }

    func testInvalidStoredValueFallsBackToDefault() {
        defaults.set(Data("junk".utf8), forKey: Shortcut.defaultsKey)
        XCTAssertEqual(Shortcut.stored(in: defaults), .default)
        Shortcut(keyCode: KeyCode.e, modifiers: 0).store(in: defaults)  // invalid → not saved
        XCTAssertEqual(Shortcut.stored(in: defaults), .default)
    }

    func testResetRemovesCustomValue() {
        Shortcut(keyCode: space, modifiers: ctrl | opt).store(in: defaults)
        Shortcut.reset(in: defaults)
        XCTAssertEqual(Shortcut.stored(in: defaults), .default)
    }

    // MARK: display

    func testDisplayUsesMacModifierOrder() {
        XCTAssertEqual(Shortcut.default.display(keyName: "e"), "⌥E")
        XCTAssertEqual(Shortcut(keyCode: space, modifiers: cmd | shift | opt | ctrl).display(keyName: "Space"),
                       "⌃⌥⇧⌘Space")
    }
}
