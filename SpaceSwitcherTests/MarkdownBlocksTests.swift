import XCTest
@testable import SpaceSwitcher

final class MarkdownBlocksTests: XCTestCase {
    private func kinds(_ text: String) -> [MarkdownBlock.Kind] {
        MarkdownBlocks.parse(text).map(\.kind)
    }

    func testHeadings() {
        XCTAssertEqual(kinds("# 제목\n## 소제목\n### 작은 제목"),
                       [.heading(level: 1, text: "제목"), .heading(level: 2, text: "소제목"), .heading(level: 3, text: "작은 제목")])
        XCTAssertEqual(kinds("#해시태그"), [.paragraph("#해시태그")])   // needs a space, like CommonMark
    }

    func testBulletsWithIndent() {
        XCTAssertEqual(kinds("- 하나\n* 둘\n  - 안쪽"),
                       [.bullet(level: 0, text: "하나"), .bullet(level: 0, text: "둘"), .bullet(level: 1, text: "안쪽")])
    }

    func testNumberedList() {
        XCTAssertEqual(kinds("1. 첫째\n2) 둘째"), [.numbered(number: 1, text: "첫째"), .numbered(number: 2, text: "둘째")])
    }

    func testTasks() {
        XCTAssertEqual(kinds("- [ ] 할 일\n- [x] 끝\n* [X] 대문자"),
                       [.task(checked: false, level: 0, text: "할 일"), .task(checked: true, level: 0, text: "끝"),
                        .task(checked: true, level: 0, text: "대문자")])
    }

    func testFencedCodeBlockKeepsContentVerbatim() {
        XCTAssertEqual(kinds("```swift\nlet a = 1\n# 주석 아님\n```\n뒤"),
                       [.code(["let a = 1", "# 주석 아님"]), .paragraph("뒤")])
    }

    func testUnclosedCodeBlockRunsToEnd() {
        XCTAssertEqual(kinds("```\n코드"), [.code(["코드"])])
    }

    func testQuoteRuleAndBlank() {
        XCTAssertEqual(kinds("> 인용\n---\n\n문단"), [.quote("인용"), .rule, .blank, .paragraph("문단")])
    }

    // Each block remembers its source line so a checkbox click can edit exactly that line.
    func testBlocksKnowTheirSourceLine() {
        let blocks = MarkdownBlocks.parse("# 오늘\n\n```\nx\n```\n- [ ] 할 일")
        XCTAssertEqual(blocks.last?.line, 5)
        XCTAssertEqual(blocks.first?.line, 0)
    }

    // MARK: checkbox toggle

    func testToggleTaskFlipsOnlyThatLine() {
        let text = "- [ ] 하나\n- [ ] 둘\n본문 [ ] 그대로"
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: text, line: 1), "- [ ] 하나\n- [x] 둘\n본문 [ ] 그대로")
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "  * [x] 끝", line: 0), "  * [ ] 끝")
    }

    func testToggleOnNonTaskLineChangesNothing() {
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "그냥 [ ] 문장", line: 0), "그냥 [ ] 문장")
        XCTAssertEqual(MarkdownBlocks.toggleTask(in: "- [ ] 하나", line: 7), "- [ ] 하나")
    }
}
