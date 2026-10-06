import XCTest
@testable import SpaceSwitcher

/// #27: the editor writes as you type; what to do when the file changes underneath it.
final class MemoSyncTests: XCTestCase {
    func testOwnWriteEchoIsIgnored() {
        var sync = MemoSync(loaded: "a")
        sync.didSave("a\nb\n")
        // The store trims what it writes; the watcher reports that back.
        XCTAssertEqual(sync.incoming("a\nb", editorText: "a\nb\n"), .ignore)
    }

    func testOutsideEditReplacesAnUntouchedEditor() {
        let sync = MemoSync(loaded: "a")
        XCTAssertEqual(sync.incoming("changed in Obsidian", editorText: "a"), .replace)
    }

    // Typing not yet saved wins; it overwrites the file on the next save.
    func testUnsavedTypingWinsOverOutsideEdit() {
        let sync = MemoSync(loaded: "a")
        XCTAssertEqual(sync.incoming("changed in Obsidian", editorText: "a typed"), .keepLocal)
    }

    func testDeletedFileIsEmpty() {
        let sync = MemoSync(loaded: "a")
        XCTAssertEqual(sync.incoming(nil, editorText: "a"), .replace)
        XCTAssertEqual(MemoSync(loaded: nil).incoming(nil, editorText: ""), .ignore)
    }

    func testNeedsSave() {
        var sync = MemoSync(loaded: "a")
        XCTAssertFalse(sync.needsSave("a\n"))        // only whitespace differs
        XCTAssertTrue(sync.needsSave("ab"))
        sync.didSave("ab")
        XCTAssertFalse(sync.needsSave("ab"))
    }
}
