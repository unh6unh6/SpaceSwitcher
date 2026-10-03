import XCTest
@testable import SpaceSwitcher

final class ProblemNoticesTests: XCTestCase {
    private func state(ax: Bool = false, off: [Int] = [], dock: Bool = false) -> ProblemState {
        ProblemState(accessibilityMissing: ax, desktopsWithoutShortcut: off, dockIgnoresShortcuts: dock)
    }

    func testNothingNewNothingShown() {
        XCTAssertEqual(ProblemNotices.new(previous: state(), current: state(), shortcutsMuted: false), [])
        XCTAssertEqual(ProblemNotices.new(previous: state(dock: true), current: state(dock: true), shortcutsMuted: false), [])
    }

    func testEachProblemAppearsOnceWhenItStarts() {
        XCTAssertEqual(ProblemNotices.new(previous: state(), current: state(ax: true), shortcutsMuted: false), [.accessibility])
        XCTAssertEqual(ProblemNotices.new(previous: state(), current: state(dock: true), shortcutsMuted: false), [.dock])
        XCTAssertEqual(ProblemNotices.new(previous: state(), current: state(off: [3]), shortcutsMuted: false), [.shortcutsOff([3])])
    }

    // Most important first; the popover shows the first one.
    func testOrderedByImportance() {
        let notices = ProblemNotices.new(previous: state(), current: state(ax: true, off: [2], dock: true), shortcutsMuted: false)
        XCTAssertEqual(notices, [.accessibility, .dock, .shortcutsOff([2])])
    }

    // Adding another desktop without a shortcut is new information; the same list is not.
    func testShortcutsNoticeOnlyForNewlyAffectedDesktops() {
        XCTAssertEqual(ProblemNotices.new(previous: state(off: [3]), current: state(off: [3]), shortcutsMuted: false), [])
        XCTAssertEqual(ProblemNotices.new(previous: state(off: [3]), current: state(off: [3, 4]), shortcutsMuted: false),
                       [.shortcutsOff([3, 4])])
        XCTAssertEqual(ProblemNotices.new(previous: state(off: [3, 4]), current: state(off: [3]), shortcutsMuted: false), [])
    }

    func testMutedShortcutsNeverPopUp() {
        XCTAssertEqual(ProblemNotices.new(previous: state(), current: state(off: [3]), shortcutsMuted: true), [])
    }

    func testProblemThatComesBackIsShownAgain() {
        XCTAssertEqual(ProblemNotices.new(previous: state(dock: false), current: state(dock: true), shortcutsMuted: false), [.dock])
    }

    // MARK: menu bar warning mark

    func testWarningMark() {
        XCTAssertFalse(ProblemNotices.needsWarningMark(state(), shortcutsMuted: false))
        XCTAssertTrue(ProblemNotices.needsWarningMark(state(ax: true), shortcutsMuted: true))
        XCTAssertTrue(ProblemNotices.needsWarningMark(state(dock: true), shortcutsMuted: true))
        XCTAssertTrue(ProblemNotices.needsWarningMark(state(off: [3]), shortcutsMuted: false))
        XCTAssertFalse(ProblemNotices.needsWarningMark(state(off: [3]), shortcutsMuted: true))   // user said "don't remind me"
    }

    func testMuteSettingRoundTrip() {
        let suite = "SpaceSwitcherTests.ProblemNotices"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        XCTAssertFalse(ProblemNotices.shortcutsMuted(in: defaults))
        ProblemNotices.setShortcutsMuted(true, in: defaults)
        XCTAssertTrue(ProblemNotices.shortcutsMuted(in: defaults))
    }
}
