import XCTest
@testable import SpaceSwitcher

/// #26 follow-up: an unsaved overlay edit stays with its desktop while the user is elsewhere, and
/// survives the app quitting or crashing.
final class MemoDraftsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SpaceSwitcherTests.MemoDrafts"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    func testDraftBelongsToItsDesktopOnly() {
        var drafts = MemoDrafts()
        drafts.park("A 고치는 중", for: "A")
        XCTAssertNil(drafts.draft(for: "B"))
        XCTAssertEqual(drafts.draft(for: "A"), "A 고치는 중")
        drafts.discard(for: "A")                      // saved or cancelled
        XCTAssertNil(drafts.draft(for: "A"))
    }

    func testEachDesktopKeepsItsOwnDraft() {
        var drafts = MemoDrafts()
        drafts.park("a", for: "A")
        drafts.park("b", for: "B")
        XCTAssertEqual(drafts.draft(for: "B"), "b")
        XCTAssertEqual(drafts.draft(for: "A"), "a")
    }

    func testOrphansAreDraftsOfRemovedDesktops() {
        var drafts = MemoDrafts()
        drafts.park("a", for: "A")
        drafts.park("gone", for: "GONE")
        XCTAssertEqual(drafts.takeOrphans(keeping: ["A"]), ["gone"])
        XCTAssertEqual(drafts.takeOrphans(keeping: ["A"]), [])
        XCTAssertEqual(drafts.draft(for: "A"), "a")
    }

    // Quit or crash mid-edit: the text is still there on the next launch (decided 2026-10-07).
    func testDraftsSurviveRestart() {
        var drafts = MemoDrafts(persistingAs: "drafts", in: defaults)
        drafts.park("a", for: "A")
        drafts.park("b", for: "B")
        drafts.discard(for: "B")
        let reloaded = MemoDrafts(persistingAs: "drafts", in: defaults)
        XCTAssertEqual(reloaded.draft(for: "A"), "a")
        XCTAssertNil(reloaded.draft(for: "B"))
    }
}
