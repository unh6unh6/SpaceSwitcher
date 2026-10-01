import XCTest
@testable import SpaceSwitcher

final class MenuBarTitleTests: XCTestCase {
    private func title(_ style: MenuBarTitle.Style, current: Int?, count: Int = 4,
                       name: String? = "업무", maxLength: Int = 20) -> String {
        MenuBarTitle.text(style: style, currentIndex: current, desktopCount: count, name: name, maxLength: maxLength)
    }

    func testNameOnly() {
        XCTAssertEqual(title(.name, current: 2), "업무")
        XCTAssertEqual(title(.name, current: 3, name: nil), "데스크탑 3")
    }

    func testNumberAndName() {
        XCTAssertEqual(title(.numberAndName, current: 2), "2 업무")
        XCTAssertEqual(title(.numberAndName, current: 3, name: nil), "3 데스크탑 3")
    }

    func testDots() {
        XCTAssertEqual(title(.dots, current: 2), "○ ● ○ ○")
        XCTAssertEqual(title(.dotsAndName, current: 2), "○ ● ○ ○ 업무")
    }

    // More than nine dots stop being readable at a glance.
    func testDotsCollapseToFractionAboveNine() {
        XCTAssertEqual(title(.dots, current: 2, count: 12), "2/12")
        XCTAssertEqual(title(.dotsAndName, current: 2, count: 12), "2/12 업무")
        XCTAssertEqual(title(.dots, current: 9, count: 9), "○ ○ ○ ○ ○ ○ ○ ○ ●")
    }

    func testNumberOnly() {
        XCTAssertEqual(title(.number, current: 2), "2")
    }

    func testNameIsTruncatedToMaxLength() {
        let long = String(repeating: "가", count: 25)
        XCTAssertEqual(title(.name, current: 1, name: long, maxLength: 10), String(repeating: "가", count: 9) + "…")
        XCTAssertEqual(title(.numberAndName, current: 1, name: long, maxLength: 10), "1 " + String(repeating: "가", count: 9) + "…")
        XCTAssertEqual(title(.name, current: 1, name: "짧음", maxLength: 10), "짧음")
    }

    // On a fullscreen app Space there is no current desktop.
    func testFullscreen() {
        XCTAssertEqual(title(.name, current: nil), "전체화면")
        XCTAssertEqual(title(.numberAndName, current: nil), "전체화면")
        XCTAssertEqual(title(.dots, current: nil), "○ ○ ○ ○")
        XCTAssertEqual(title(.number, current: nil), "–")
    }

    // MARK: settings

    func testSettingsDefaultsAndRoundTrip() {
        let suite = "SpaceSwitcherTests.MenuBarTitle"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        XCTAssertEqual(MenuBarTitle.Settings.load(from: defaults), MenuBarTitle.Settings(style: .dotsAndName, maxLength: 20))

        MenuBarTitle.Settings(style: .numberAndName, maxLength: 10).save(to: defaults)
        XCTAssertEqual(MenuBarTitle.Settings.load(from: defaults), MenuBarTitle.Settings(style: .numberAndName, maxLength: 10))

        defaults.set("rainbow", forKey: "menuBarStyle")
        XCTAssertEqual(MenuBarTitle.Settings.load(from: defaults).style, .dotsAndName)
    }
}
