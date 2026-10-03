import XCTest
@testable import SpaceSwitcher

final class SwitchPlannerTests: XCTestCase {
    private let ctrl1 = KeyCombo(keyCode: 18, flags: 262144)
    private let ctrl2 = KeyCombo(keyCode: 19, flags: 262144)
    private let left = KeyCombo(keyCode: 123, flags: 8650752)
    private let right = KeyCombo(keyCode: 124, flags: 8650752)

    private var allKeys: [Int: KeyCombo] { [118: ctrl1, 119: ctrl2, 79: left, 81: right] }

    private func desktop(_ index: Int, position: Int, current: Bool = false) -> Space {
        Space(id: "D\(index)", managedID: 100 + index, index: index, position: position, isCurrent: current)
    }

    func testAlreadyThereDoesNothing() {
        let plan = SwitchPlanner.plan(to: desktop(2, position: 1, current: true), currentPosition: 1, hotkeys: allKeys)
        XCTAssertEqual(plan, .none)
    }

    func testUsesDirectShortcutWhenEnabled() {
        let plan = SwitchPlanner.plan(to: desktop(2, position: 1), currentPosition: 0, hotkeys: allKeys)
        XCTAssertEqual(plan, .direct(ctrl2))
    }

    func testFallsBackToRightArrowsWhenShortcutMissing() {
        let plan = SwitchPlanner.plan(to: desktop(3, position: 2), currentPosition: 0, hotkeys: allKeys)
        XCTAssertEqual(plan, .arrows(right, count: 2))
    }

    func testFallsBackToLeftArrows() {
        let plan = SwitchPlanner.plan(to: desktop(3, position: 2), currentPosition: 4, hotkeys: [79: left, 81: right])
        XCTAssertEqual(plan, .arrows(left, count: 2))
    }

    // Ctrl+←/→ also steps through fullscreen Spaces, so the count uses raw positions, not desktop indexes.
    func testArrowCountIncludesFullscreenSpacesInBetween() {
        let plan = SwitchPlanner.plan(to: desktop(2, position: 2), currentPosition: 0, hotkeys: [81: right])
        XCTAssertEqual(plan, .arrows(right, count: 2))
    }

    func testDesktopBeyondSixteenUsesArrows() {
        let plan = SwitchPlanner.plan(to: desktop(17, position: 16), currentPosition: 15, hotkeys: allKeys)
        XCTAssertEqual(plan, .arrows(right, count: 1))
    }

    func testDirectWorksEvenWhenCurrentPositionUnknown() {
        let plan = SwitchPlanner.plan(to: desktop(1, position: 0), currentPosition: nil, hotkeys: allKeys)
        XCTAssertEqual(plan, .direct(ctrl1))
    }

    func testNoPathWhenNothingEnabled() {
        XCTAssertEqual(SwitchPlanner.plan(to: desktop(2, position: 1), currentPosition: 0, hotkeys: [:]), .none)
        XCTAssertEqual(SwitchPlanner.plan(to: desktop(2, position: 1), currentPosition: nil, hotkeys: [81: right]), .none)
    }

    // MARK: Dock ignoring "Switch to Desktop N" (#22)

    func testAvoidDirectUsesArrowsEvenWhenShortcutExists() {
        let plan = SwitchPlanner.plan(to: desktop(2, position: 1), currentPosition: 0, hotkeys: allKeys, avoidDirect: true)
        XCTAssertEqual(plan, .arrows(right, count: 1))
    }

    func testAvoidDirectWithoutKnownPositionDoesNothing() {
        XCTAssertEqual(SwitchPlanner.plan(to: desktop(2, position: 1), currentPosition: nil, hotkeys: allKeys, avoidDirect: true), .none)
    }

    // After a direct shortcut: arrived → nothing more; still elsewhere → finish with arrows from where we are.
    func testFollowUpAfterDirect() {
        XCTAssertEqual(SwitchPlanner.followUp(targetPosition: 2, landedPosition: 2, hotkeys: allKeys), .none)
        XCTAssertEqual(SwitchPlanner.followUp(targetPosition: 2, landedPosition: 0, hotkeys: allKeys), .arrows(right, count: 2))
        XCTAssertEqual(SwitchPlanner.followUp(targetPosition: 0, landedPosition: 3, hotkeys: allKeys), .arrows(left, count: 3))
        XCTAssertEqual(SwitchPlanner.followUp(targetPosition: 2, landedPosition: nil, hotkeys: allKeys), .none)
        XCTAssertEqual(SwitchPlanner.followUp(targetPosition: 2, landedPosition: 0, hotkeys: [:]), .none)
    }
}
