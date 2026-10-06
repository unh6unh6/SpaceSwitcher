import XCTest
@testable import SpaceSwitcher

/// #25: each desktop's memo reopens where it was being read.
final class MemoScrollMemoryTests: XCTestCase {
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
