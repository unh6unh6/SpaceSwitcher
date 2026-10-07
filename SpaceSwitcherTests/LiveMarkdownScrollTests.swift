import AppKit
import XCTest
@testable import SpaceSwitcher

/// #28: a long memo put in by code (not typed) must make the editor scrollable.
final class LiveMarkdownScrollTests: XCTestCase {
    private let long = (1...60).map { "- [ ] 줄 \($0) **굵게**" }.joined(separator: "\n")

    private func makeWindow(height: CGFloat = 200) -> (NSWindow, NSScrollView, LiveMarkdownTextView) {
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 300, height: height), styleMask: [.titled], backing: .buffered, defer: false)
        let (scroll, textView) = LiveMarkdownEditor.makeScrollView()
        scroll.frame = window.contentView!.bounds
        scroll.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(scroll)
        textView.minSize = CGSize(width: 0, height: scroll.contentSize.height)
        return (window, scroll, textView)
    }

    private func settle() { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }

    private func assertScrollable(_ scroll: NSScrollView, _ textView: LiveMarkdownTextView, _ message: String,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let content = textView.layoutManager!.usedRect(for: textView.textContainer!).height
        XCTAssertGreaterThan(content, scroll.contentSize.height, "test text is long enough", file: file, line: line)
        XCTAssertGreaterThanOrEqual(textView.frame.height, content, "\(message): document as tall as its text", file: file, line: line)
        XCTAssertEqual(textView.frame.width, scroll.contentSize.width, accuracy: 1, "\(message): document as wide as the view", file: file, line: line)
        scroll.contentView.scroll(to: CGPoint(x: 0, y: 150))
        scroll.reflectScrolledClipView(scroll.contentView)
        XCTAssertEqual(scroll.contentView.bounds.minY, 150, accuracy: 1, "\(message): can scroll", file: file, line: line)
        scroll.contentView.scroll(to: .zero)
    }

    func testLongMemoPutInByCodeIsScrollable() {
        let (_, scroll, textView) = makeWindow()
        textView.setSource(long)
        settle()
        assertScrollable(scroll, textView, "fresh editor")
    }

    func testReplacingShortWithLongIsScrollable() {
        let (_, scroll, textView) = makeWindow()
        textView.setSource("짧음")
        settle()
        textView.setSource(long)
        settle()
        assertScrollable(scroll, textView, "short → long")
    }

    func testSameTextAgainStaysScrollable() {
        let (_, scroll, textView) = makeWindow()
        textView.setSource(long)
        textView.setSource(long)
        settle()
        assertScrollable(scroll, textView, "same text twice")
    }

    func testOneLongWrappedLine() {
        let (_, scroll, textView) = makeWindow()
        textView.setSource(String(repeating: "자동 줄바꿈되는 아주 긴 한 줄 ", count: 60))
        settle()
        assertScrollable(scroll, textView, "wrapped line")
    }

    func testShrinkingTheWindowMakesItScrollable() {
        let (window, scroll, textView) = makeWindow(height: 2000)
        textView.setSource(long)
        settle()
        window.setContentSize(CGSize(width: 300, height: 200))
        textView.minSize = CGSize(width: 0, height: scroll.contentSize.height)
        settle()
        assertScrollable(scroll, textView, "window shrunk")
    }

    // Styles that change line height (headings) must grow the document too.
    func testHeadingsCountTowardsHeight() {
        let (_, scroll, textView) = makeWindow()
        textView.setSource((1...30).map { "# 제목 \($0)" }.joined(separator: "\n"))
        settle()
        assertScrollable(scroll, textView, "headings")
    }
}
