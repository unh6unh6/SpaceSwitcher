import XCTest
@testable import SpaceSwitcher

final class MRUTrackerTests: XCTestCase {
    func testVisitMovesToFront() {
        var mru = MRUTracker()
        mru.visit("A"); mru.visit("B"); mru.visit("C"); mru.visit("A")
        XCTAssertEqual(mru.order, ["A", "C", "B"])
    }

    func testRepeatedVisitDoesNotDuplicate() {
        var mru = MRUTracker()
        mru.visit("A"); mru.visit("A")
        XCTAssertEqual(mru.order, ["A"])
    }

    func testPreviousIsMostRecentOtherThanCurrent() {
        var mru = MRUTracker()
        mru.visit("A"); mru.visit("B"); mru.visit("C")
        XCTAssertEqual(mru.previous(current: "C", existing: ["A", "B", "C"]), "B")
    }

    // A desktop that was deleted must not be offered as the "previous" one.
    func testPreviousSkipsDesktopsThatNoLongerExist() {
        var mru = MRUTracker()
        mru.visit("A"); mru.visit("GONE"); mru.visit("C")
        XCTAssertEqual(mru.previous(current: "C", existing: ["A", "C"]), "A")
    }

    func testPreviousIsNilWithoutHistory() {
        var mru = MRUTracker()
        mru.visit("A")
        XCTAssertNil(mru.previous(current: "A", existing: ["A", "B"]))
    }

    // MARK: initial selection

    private func desktops(_ ids: [String], current: String?) -> [Space] {
        ids.enumerated().map { i, id in
            Space(id: id, managedID: i, index: i + 1, position: i, isCurrent: id == current)
        }
    }

    func testInitialSelectionIsPreviousDesktop() {
        var mru = MRUTracker()
        mru.visit("C"); mru.visit("A")
        XCTAssertEqual(mru.initialSelection(.previous, in: desktops(["A", "B", "C"], current: "A")), 2)
    }

    func testInitialSelectionFallsBackToNextDesktop() {
        let mru = MRUTracker()
        XCTAssertEqual(mru.initialSelection(.previous, in: desktops(["A", "B", "C"], current: "C")), 0)  // wraps
        XCTAssertEqual(mru.initialSelection(.previous, in: desktops(["A", "B", "C"], current: "A")), 1)
    }

    func testInitialSelectionOnFullscreenIsFirstRow() {
        let mru = MRUTracker()
        XCTAssertEqual(mru.initialSelection(.previous, in: desktops(["A", "B"], current: nil)), 0)
    }

    // Default since 2026-09-30 (user preference): start on the current desktop.
    func testCurrentModeSelectsCurrentDesktop() {
        var mru = MRUTracker()
        mru.visit("C"); mru.visit("B")
        XCTAssertEqual(mru.initialSelection(.current, in: desktops(["A", "B", "C"], current: "B")), 1)
    }

    func testCurrentModeOnFullscreenIsFirstRow() {
        XCTAssertEqual(MRUTracker().initialSelection(.current, in: desktops(["A", "B"], current: nil)), 0)
    }

    func testDefaultModeIsCurrent() {
        XCTAssertEqual(InitialSelection.default, .current)
    }

    func testInitialSelectionWithOneDesktopIsItself() {
        let mru = MRUTracker()
        XCTAssertEqual(mru.initialSelection(.previous, in: desktops(["A"], current: "A")), 0)
    }
}
