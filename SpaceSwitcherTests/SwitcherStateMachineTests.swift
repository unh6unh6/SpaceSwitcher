import XCTest
@testable import SpaceSwitcher

/// Covers every transition in SPEC §3.1.
final class SwitcherStateMachineTests: XCTestCase {
    private func machine(count: Int = 4, initial: Int = 1) -> SwitcherStateMachine {
        SwitcherStateMachine { (count: count, initial: initial) }
    }

    /// Opens the panel and returns the machine in Holding.
    private func holding(count: Int = 4, initial: Int = 1) -> SwitcherStateMachine {
        var m = machine(count: count, initial: initial)
        _ = m.handle(.trigger(shift: false))
        return m
    }

    /// Short press: open, release after one press → Sticky.
    private func sticky(count: Int = 4, initial: Int = 1) -> SwitcherStateMachine {
        var m = holding(count: count, initial: initial)
        _ = m.handle(.modifierReleased)
        return m
    }

    // MARK: Idle

    func testTriggerFromIdleShowsPanelAtInitialSelection() {
        var m = machine(initial: 2)
        XCTAssertEqual(m.handle(.trigger(shift: false)), .show(selection: 2))
        XCTAssertEqual(m.state, .holding(selection: 2, pressCount: 1))
    }

    func testIdleIgnoresEverythingElse() {
        var m = machine()
        for event: SwitcherStateMachine.Event in [.modifierReleased, .moveUp, .moveDown, .digit(1),
                                                 .confirm, .cancel, .select(0), .highlight(0), .beginRename, .endRename, .clickOutside] {
            XCTAssertNil(m.handle(event), "\(event)")
            XCTAssertEqual(m.state, .idle)
        }
        XCTAssertFalse(m.isCapturingKeys)
    }

    // MARK: Holding

    func testHoldingTriggerAdvancesAndWraps() {
        var m = holding(count: 3, initial: 1)
        XCTAssertEqual(m.handle(.trigger(shift: false)), .select(2))
        XCTAssertEqual(m.handle(.trigger(shift: false)), .select(0))
        XCTAssertEqual(m.state, .holding(selection: 0, pressCount: 3))
    }

    func testHoldingShiftTriggerGoesBackAndWraps() {
        var m = holding(count: 3, initial: 0)
        XCTAssertEqual(m.handle(.trigger(shift: true)), .select(2))
        XCTAssertEqual(m.state, .holding(selection: 2, pressCount: 2))
    }

    func testReleaseAfterSeveralPressesSwitches() {  // cycle mode
        var m = holding(initial: 1)
        _ = m.handle(.trigger(shift: false))
        XCTAssertEqual(m.handle(.modifierReleased), .switchTo(2))
        XCTAssertEqual(m.state, .idle)
    }

    func testReleaseAfterOnePressGoesSticky() {  // popup mode
        var m = holding(initial: 1)
        XCTAssertNil(m.handle(.modifierReleased))
        XCTAssertEqual(m.state, .sticky(selection: 1))
        XCTAssertTrue(m.isCapturingKeys)
    }

    func testEscapeInHoldingHides() {
        var m = holding()
        XCTAssertEqual(m.handle(.cancel), .hide)
        XCTAssertEqual(m.state, .idle)
    }

    func testClickOutsideInHoldingHides() {
        var m = holding()
        XCTAssertEqual(m.handle(.clickOutside), .hide)
        XCTAssertEqual(m.state, .idle)
    }

    // MARK: Sticky

    func testStickyArrowsMoveAndWrap() {
        var m = sticky(count: 3, initial: 0)
        XCTAssertEqual(m.handle(.moveUp), .select(2))
        XCTAssertEqual(m.handle(.moveDown), .select(0))
        XCTAssertEqual(m.handle(.moveDown), .select(1))
    }

    func testStickyTriggerMovesBothWays() {  // K, Shift+K, and M+K again
        var m = sticky(count: 4, initial: 1)
        XCTAssertEqual(m.handle(.trigger(shift: false)), .select(2))
        XCTAssertEqual(m.handle(.trigger(shift: true)), .select(1))
        XCTAssertEqual(m.state, .sticky(selection: 1))
    }

    func testStickyIgnoresModifierRelease() {
        var m = sticky(initial: 1)
        _ = m.handle(.trigger(shift: false))
        XCTAssertNil(m.handle(.modifierReleased))
        XCTAssertEqual(m.state, .sticky(selection: 2))
    }

    func testStickyDigitSwitchesToThatDesktop() {
        var m = sticky(count: 4)
        XCTAssertEqual(m.handle(.digit(3)), .switchTo(2))
        XCTAssertEqual(m.state, .idle)
    }

    func testStickyDigitOutOfRangeIsIgnored() {
        var m = sticky(count: 4, initial: 1)
        XCTAssertNil(m.handle(.digit(5)))
        XCTAssertNil(m.handle(.digit(0)))
        XCTAssertEqual(m.state, .sticky(selection: 1))
    }

    func testStickyEnterSwitchesToSelection() {
        var m = sticky(initial: 1)
        _ = m.handle(.moveDown)
        XCTAssertEqual(m.handle(.confirm), .switchTo(2))
        XCTAssertEqual(m.state, .idle)
    }

    func testStickyClickSwitchesToClickedRow() {
        var m = sticky()
        XCTAssertEqual(m.handle(.select(3)), .switchTo(3))
        XCTAssertEqual(m.state, .idle)
    }

    func testStickyEscapeAndClickOutsideHide() {
        var m = sticky()
        XCTAssertEqual(m.handle(.cancel), .hide)
        m = sticky()
        XCTAssertEqual(m.handle(.clickOutside), .hide)
        XCTAssertEqual(m.state, .idle)
    }

    // MARK: Rename (R / double-click)

    func testRenameStopsKeyCaptureUntilDone() {
        var m = sticky(initial: 2)
        XCTAssertEqual(m.handle(.beginRename), .rename(2))
        XCTAssertEqual(m.state, .renaming(selection: 2))
        XCTAssertFalse(m.isCapturingKeys)  // the text field needs the keystrokes

        XCTAssertNil(m.handle(.digit(1)))
        XCTAssertNil(m.handle(.trigger(shift: false)))
        XCTAssertEqual(m.handle(.endRename), .select(2))
        XCTAssertEqual(m.state, .sticky(selection: 2))
    }

    func testClickOutsideWhileRenamingHides() {
        var m = sticky()
        _ = m.handle(.beginRename)
        XCTAssertEqual(m.handle(.clickOutside), .hide)
        XCTAssertEqual(m.state, .idle)
    }

    // Double-click = highlight that row, then rename it.
    func testHighlightMovesSelectionWithoutSwitching() {
        var m = sticky(count: 4, initial: 0)
        XCTAssertEqual(m.handle(.highlight(3)), .select(3))
        XCTAssertEqual(m.state, .sticky(selection: 3))
        XCTAssertEqual(m.handle(.beginRename), .rename(3))
    }

    func testHighlightOutOfRangeIgnored() {
        var m = sticky(count: 2, initial: 0)
        XCTAssertNil(m.handle(.highlight(5)))
        XCTAssertEqual(m.state, .sticky(selection: 0))
    }

    func testHighlightInHoldingKeepsPressCount() {
        var m = holding(count: 4, initial: 0)
        XCTAssertEqual(m.handle(.highlight(2)), .select(2))
        XCTAssertEqual(m.state, .holding(selection: 2, pressCount: 1))
    }

    func testRenameNotAvailableWhileHolding() {
        var m = holding()
        XCTAssertNil(m.handle(.beginRename))
    }

    // MARK: Edge cases

    func testSingleDesktopStillShowsPanel() {
        var m = machine(count: 1, initial: 0)
        XCTAssertEqual(m.handle(.trigger(shift: false)), .show(selection: 0))
        XCTAssertEqual(m.handle(.trigger(shift: false)), .select(0))
    }

    func testNoDesktopsDoesNotOpen() {
        var m = machine(count: 0, initial: 0)
        XCTAssertNil(m.handle(.trigger(shift: false)))
        XCTAssertEqual(m.state, .idle)
    }

    func testReopenAfterCloseRereadsList() {
        var calls = 0
        var m = SwitcherStateMachine { calls += 1; return (count: 3, initial: calls % 3) }
        _ = m.handle(.trigger(shift: false))
        _ = m.handle(.cancel)
        XCTAssertEqual(m.handle(.trigger(shift: false)), .show(selection: 2))
        XCTAssertEqual(calls, 2)
    }
}
