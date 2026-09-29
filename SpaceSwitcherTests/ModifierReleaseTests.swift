import CoreGraphics
import XCTest
@testable import SpaceSwitcher

final class ModifierReleaseTests: XCTestCase {
    private let ctrl = CGEventFlags.maskControl.rawValue
    private let opt = CGEventFlags.maskAlternate.rawValue
    private let fn = CGEventFlags.maskSecondaryFn.rawValue

    func testCtrlShortcutReleasesControl() {
        XCTAssertEqual(ModifierRelease.keyUps(for: ctrl, before: 0),
                       [.init(keyCode: 59, flagsAfter: 0)])
    }

    // Ctrl+→ carries the Fn bit (0x840000 in the plist); both must be let go.
    func testArrowShortcutReleasesControlAndFn() {
        XCTAssertEqual(ModifierRelease.keyUps(for: ctrl | fn, before: 0), [
            .init(keyCode: 59, flagsAfter: fn),
            .init(keyCode: 63, flagsAfter: 0),
        ])
    }

    // A modifier the user is physically holding must stay down.
    func testKeepsModifiersThatWereAlreadyHeld() {
        XCTAssertEqual(ModifierRelease.keyUps(for: ctrl, before: ctrl), [])
        XCTAssertEqual(ModifierRelease.keyUps(for: ctrl, before: opt),
                       [.init(keyCode: 59, flagsAfter: opt)])
    }

    func testNoModifiersNothingToRelease() {
        XCTAssertEqual(ModifierRelease.keyUps(for: 0, before: 0), [])
    }
}
