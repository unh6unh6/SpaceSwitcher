import XCTest
@testable import SpaceSwitcher

/// #27: which characters of the source get which live-preview style.
final class MarkdownLiveStyleTests: XCTestCase {
    /// Runs as (text covered, kind, line) — easier to read than raw ranges.
    private func runs(_ text: String) -> [(String, LiveStyleRun.Kind, Int)] {
        MarkdownLiveStyle.runs(in: text).map { ((text as NSString).substring(with: $0.range), $0.kind, $0.line) }
    }

    private func assertRuns(_ text: String, _ expected: [(String, LiveStyleRun.Kind)], line: Int = 0,
                            file: StaticString = #filePath, lineNumber: UInt = #line) {
        let got = runs(text)
        XCTAssertEqual(got.map(\.0), expected.map(\.0), "covered text", file: file, line: lineNumber)
        XCTAssertEqual(got.map(\.1), expected.map(\.1), "kinds", file: file, line: lineNumber)
        XCTAssertTrue(got.allSatisfy { $0.2 == line }, "line", file: file, line: lineNumber)
    }

    func testPlainTextHasNoRuns() {
        XCTAssertTrue(MarkdownLiveStyle.runs(in: "그냥 문장\n두 번째").isEmpty)
    }

    func testHeadingHidesHashesAndStylesTheRest() {
        assertRuns("## 오늘 할 일", [("## ", .syntax), ("오늘 할 일", .heading(2))])
        assertRuns("#### 작게", [("#### ", .syntax), ("작게", .heading(3))])   // 4–6 look like 3
        XCTAssertTrue(runs("#태그").isEmpty)                                    // no space: not a heading
    }

    func testBulletMarker() {
        assertRuns("- 사과", [("-", .bullet)])
        assertRuns("  * 배", [("*", .bullet)])
    }

    func testTaskHidesDashAndDrawsBox() {
        assertRuns("- [ ] 배포", [("- ", .syntax), ("[ ]", .task(checked: false))])
        assertRuns("- [x] 정리", [("- ", .syntax), ("[x]", .task(checked: true)), ("정리", .done)])
    }

    func testInlineStyles() {
        assertRuns("a **굵게** b", [("**", .syntax), ("굵게", .bold), ("**", .syntax)])
        assertRuns("*기울임*", [("*", .syntax), ("기울임", .italic), ("*", .syntax)])
        assertRuns("`code`", [("`", .syntax), ("code", .code), ("`", .syntax)])
        assertRuns("~~취소~~", [("~~", .syntax), ("취소", .strike), ("~~", .syntax)])
        assertRuns("[링크](https://a.b)", [("[", .syntax), ("링크", .link("https://a.b")), ("](https://a.b)", .syntax)])
    }

    func testUnderscoresInsideWordsAreNotItalic() {
        XCTAssertTrue(runs("snake_case_name").isEmpty)
        assertRuns("_강조_", [("_", .syntax), ("강조", .italic), ("_", .syntax)])
    }

    func testUnclosedOrEmptyMarkersStayPlain() {
        XCTAssertTrue(runs("**열기만").isEmpty)
        XCTAssertTrue(runs("****").isEmpty)
        XCTAssertTrue(runs("2 * 3 = 6").isEmpty)
    }

    func testInlineInsideListAndHeading() {
        assertRuns("- **중요**", [("-", .bullet), ("**", .syntax), ("중요", .bold), ("**", .syntax)])
        assertRuns("# `x`", [("# ", .syntax), ("`x`", .heading(1)), ("`", .syntax), ("x", .code), ("`", .syntax)])
    }

    func testQuoteAndRule() {
        assertRuns("> 인용", [("> ", .syntax), ("인용", .quote)])
        assertRuns("---", [("---", .rule)])
    }

    func testCodeFenceIsNotParsedInside() {
        let r = runs("```\n**not bold**\n```")
        XCTAssertEqual(r.map(\.0), ["```", "**not bold**", "```"])
        XCTAssertEqual(r.map(\.1), [.fence, .codeBlock, .fence])
        XCTAssertEqual(r.map(\.2), [0, 1, 2])
    }

    func testLineNumbers() {
        let r = runs("plain\n- [ ] a\n## b")
        XCTAssertEqual(r.map(\.2), [1, 1, 2, 2])
    }

    func testUTF16RangesWithEmoji() {
        // An emoji is two UTF-16 units; ranges must still cover the right characters.
        assertRuns("😀 **굵게**", [("**", .syntax), ("굵게", .bold), ("**", .syntax)])
    }

    // MARK: caret lines

    func testLinesTouchedBySelection() {
        let text = "one\ntwo\nthree"
        XCTAssertEqual(MarkdownLiveStyle.lines(touching: NSRange(location: 0, length: 0), in: text), 0...0)
        XCTAssertEqual(MarkdownLiveStyle.lines(touching: NSRange(location: 5, length: 0), in: text), 1...1)
        XCTAssertEqual(MarkdownLiveStyle.lines(touching: NSRange(location: 2, length: 6), in: text), 0...2)
        XCTAssertEqual(MarkdownLiveStyle.lines(touching: NSRange(location: 13, length: 0), in: text), 2...2)  // end of text
    }

    func testLineAtOffset() {
        let text = "one\ntwo"
        XCTAssertEqual(MarkdownLiveStyle.line(at: 0, in: text), 0)
        XCTAssertEqual(MarkdownLiveStyle.line(at: 4, in: text), 1)
        XCTAssertEqual(MarkdownLiveStyle.lineCount(text), 2)
        XCTAssertEqual(MarkdownLiveStyle.lineStart(1, in: text), 4)
    }
}
