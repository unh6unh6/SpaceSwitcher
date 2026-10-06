import XCTest
@testable import SpaceSwitcher

/// #26: an edit must be saved to the desktop it was started on, not the one on screen at save time.
final class MemoEditTargetTests: XCTestCase {
    private func desktop(_ id: String, _ index: Int, current: Bool = false) -> Space {
        Space(id: id, managedID: index, index: index, position: index - 1, isCurrent: current)
    }

    func testSavesToTheDesktopTheEditStartedOn() {
        let a = desktop("A", 1)
        let spaces = [a, desktop("B", 2, current: true)]   // user moved to B while editing A's memo
        XCTAssertEqual(MemoEditTarget.resolve(editing: a, in: spaces), .save(a))
    }

    func testUsesTheFreshDesktopInfo() {
        // The desktop was reordered meanwhile: still found by id, with its new index.
        let started = desktop("A", 1)
        let now = Space(id: "A", managedID: 1, index: 3, position: 2, isCurrent: false)
        XCTAssertEqual(MemoEditTarget.resolve(editing: started, in: [desktop("B", 1), desktop("C", 2), now]), .save(now))
    }

    func testDesktopDeletedWhileEditing() {
        XCTAssertEqual(MemoEditTarget.resolve(editing: desktop("GONE", 4), in: [desktop("A", 1, current: true)]), .gone)
    }

    func testNothingBeingEdited() {
        XCTAssertEqual(MemoEditTarget.resolve(editing: nil, in: [desktop("A", 1)]), .nothing)
    }

    func testEditingTitleNamesTheTargetDesktop() {
        XCTAssertEqual(MemoEditTarget.editingTitle("업무"), "업무 (편집 중)")
    }
}
