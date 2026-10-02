import XCTest
@testable import SpaceSwitcher

final class MemoFormatTests: XCTestCase {
    // MARK: front matter

    func testParsesSpaceIDAndBody() {
        let parsed = MemoFormat.parse("---\nspace: ABC-123\n---\n## 오늘\n- [ ] 할 일\n")
        XCTAssertEqual(parsed.spaceID, "ABC-123")
        XCTAssertEqual(parsed.body, "## 오늘\n- [ ] 할 일")
    }

    func testFileWithoutFrontMatterHasNoSpace() {
        let parsed = MemoFormat.parse("# 그냥 노트\n내용")
        XCTAssertNil(parsed.spaceID)
        XCTAssertEqual(parsed.body, "# 그냥 노트\n내용")
    }

    // Users (or Obsidian) may add their own keys; they must survive a save.
    func testKeepsOtherFrontMatterKeys() {
        let original = "---\ntags: [work]\nspace: ABC\naliases: 업무\n---\n본문"
        let parsed = MemoFormat.parse(original)
        XCTAssertEqual(parsed.spaceID, "ABC")
        let written = MemoFormat.serialize(spaceID: "ABC", body: "새 본문", keeping: parsed.otherFrontMatter)
        XCTAssertEqual(written, "---\ntags: [work]\naliases: 업무\nspace: ABC\n---\n새 본문\n")
    }

    func testSerializeRoundTrip() {
        let text = MemoFormat.serialize(spaceID: "ABC", body: "첫 줄\n\n  들여쓴 줄", keeping: [])
        XCTAssertEqual(MemoFormat.parse(text).body, "첫 줄\n\n  들여쓴 줄")
        XCTAssertEqual(MemoFormat.parse(text).spaceID, "ABC")
    }

    func testUnclosedFrontMatterIsTreatedAsBody() {
        let parsed = MemoFormat.parse("---\nspace: ABC\n본문만 있음")
        XCTAssertNil(parsed.spaceID)
        XCTAssertEqual(parsed.body, "---\nspace: ABC\n본문만 있음")
    }

    func testWindowsLineEndings() {
        let parsed = MemoFormat.parse("---\r\nspace: ABC\r\n---\r\n본문\r\n")
        XCTAssertEqual(parsed.spaceID, "ABC")
        XCTAssertEqual(parsed.body, "본문")
    }

    // MARK: file names

    func testFileNameFromDesktopName() {
        XCTAssertEqual(MemoFormat.fileName(for: "업무", taken: []), "업무.md")
    }

    func testFileNameAvoidsCollisionsCaseInsensitively() {
        XCTAssertEqual(MemoFormat.fileName(for: "업무", taken: ["업무.md"]), "업무 2.md")
        XCTAssertEqual(MemoFormat.fileName(for: "Work", taken: ["work.md", "Work 2.md"]), "Work 3.md")
    }

    func testFileNameStripsPathCharacters() {
        XCTAssertEqual(MemoFormat.fileName(for: "A/B:C", taken: []), "A-B-C.md")
        XCTAssertEqual(MemoFormat.fileName(for: "  ", taken: []), "데스크탑.md")
        XCTAssertEqual(MemoFormat.fileName(for: ".숨김", taken: []), "숨김.md")
    }
}
