import XCTest
@testable import SpaceSwitcher

/// #25: each desktop's memo reopens where it was being read.
final class MemoScrollMemoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SpaceSwitcherTests.MemoScrollMemory"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    // Kept across app restarts (decided 2026-10-07).
    func testPersistedPositionSurvivesRestart() {
        var memory = MemoScrollMemory(persistingAs: "scroll", in: defaults)
        memory.set(6, for: "A")
        XCTAssertEqual(MemoScrollMemory(persistingAs: "scroll", in: defaults).position(for: "A", blockCount: 10), 6)
        XCTAssertEqual(MemoScrollMemory(persistingAs: "other", in: defaults).position(for: "A", blockCount: 10), 0)
    }

    func testPruneForgetsRemovedDesktops() {
        var memory = MemoScrollMemory(persistingAs: "scroll", in: defaults)
        memory.set(3, for: "A")
        memory.set(5, for: "GONE")
        memory.prune(keeping: ["A"])
        let reloaded = MemoScrollMemory(persistingAs: "scroll", in: defaults)
        XCTAssertEqual(reloaded.position(for: "GONE", blockCount: 10), 0)
        XCTAssertEqual(reloaded.position(for: "A", blockCount: 10), 3)
    }

    func testUnknownDesktopStartsAtTop() {
        XCTAssertEqual(MemoScrollMemory().position(for: "A", blockCount: 10), 0)
    }

    func testEachDesktopKeepsItsOwnPosition() {
        var memory = MemoScrollMemory()
        memory.set(7, for: "A")
        memory.set(2, for: "B")
        XCTAssertEqual(memory.position(for: "A", blockCount: 20), 7)
        XCTAssertEqual(memory.position(for: "B", blockCount: 20), 2)
    }

    // The memo got shorter (edited, or changed on disk): show its last block instead of nothing.
    func testShorterMemoClampsToLastBlock() {
        var memory = MemoScrollMemory()
        memory.set(30, for: "A")
        XCTAssertEqual(memory.position(for: "A", blockCount: 5), 4)
        XCTAssertEqual(memory.position(for: "A", blockCount: 0), 0)
    }

    func testNegativeIsTop() {
        var memory = MemoScrollMemory()
        memory.set(-3, for: "A")
        XCTAssertEqual(memory.position(for: "A", blockCount: 5), 0)
    }

    // No desktop (fullscreen Space) has nothing to remember.
    func testNoDesktopIsIgnored() {
        var memory = MemoScrollMemory()
        memory.set(4, for: nil)
        XCTAssertEqual(memory.position(for: nil, blockCount: 10), 0)
    }
}
