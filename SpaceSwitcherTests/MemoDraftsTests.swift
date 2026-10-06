import XCTest
@testable import SpaceSwitcher

/// #26 follow-up: an unsaved overlay edit stays with its desktop while the user is elsewhere.
final class MemoDraftsTests: XCTestCase {
    func testParkedDraftComesBackOnItsDesktopOnly() {
        var drafts = MemoDrafts()
        drafts.park("A 고치는 중", for: "A")
        XCTAssertNil(drafts.take(for: "B"))
        XCTAssertEqual(drafts.take(for: "A"), "A 고치는 중")
        XCTAssertNil(drafts.take(for: "A"))           // taken back into the editor
    }

    func testEachDesktopKeepsItsOwnDraft() {
        var drafts = MemoDrafts()
        drafts.park("a", for: "A")
        drafts.park("b", for: "B")
        XCTAssertEqual(drafts.take(for: "B"), "b")
        XCTAssertEqual(drafts.take(for: "A"), "a")
    }

    func testOrphansAreDraftsOfRemovedDesktops() {
        var drafts = MemoDrafts()
        drafts.park("a", for: "A")
        drafts.park("gone", for: "GONE")
        XCTAssertEqual(drafts.takeOrphans(keeping: ["A"]), ["gone"])
        XCTAssertEqual(drafts.takeOrphans(keeping: ["A"]), [])
        XCTAssertEqual(drafts.take(for: "A"), "a")
    }
}
