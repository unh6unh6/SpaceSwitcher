import XCTest
@testable import SpaceSwitcher

final class SpaceHUDTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SpaceSwitcherTests.SpaceHUD"

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    private func space(_ index: Int, id: String = "X") -> Space {
        Space(id: id, managedID: index, index: index, position: index - 1, isCurrent: true)
    }

    // MARK: text

    func testNamedDesktopShowsNumberAndName() {
        XCTAssertEqual(SpaceHUDContent.text(for: space(2), name: "업무"), "2 · 업무")
    }

    func testUnnamedDesktopShowsDefaultName() {
        XCTAssertEqual(SpaceHUDContent.text(for: space(3), name: nil), "데스크탑 3")
    }

    // Fullscreen app Spaces aren't in the desktop list, so there is nothing to show.
    func testNoTextWhenNotOnADesktop() {
        XCTAssertNil(SpaceHUDContent.text(for: nil, name: nil))
    }

    // MARK: settings

    func testDefaults() {
        let settings = SpaceHUDSettings.load(from: defaults)
        XCTAssertTrue(settings.isEnabled)
        XCTAssertEqual(settings.duration, .normal)
        XCTAssertEqual(settings.position, .center)
    }

    func testRoundTrip() {
        SpaceHUDSettings(isEnabled: false, duration: .long, position: .top).save(to: defaults)
        XCTAssertEqual(SpaceHUDSettings.load(from: defaults),
                       SpaceHUDSettings(isEnabled: false, duration: .long, position: .top))
    }

    func testUnknownStoredValuesFallBackToDefaults() {
        defaults.set("forever", forKey: "hudDuration")
        defaults.set("left", forKey: "hudPosition")
        let settings = SpaceHUDSettings.load(from: defaults)
        XCTAssertEqual(settings.duration, .normal)
        XCTAssertEqual(settings.position, .center)
    }

    func testDurationSeconds() {
        XCTAssertEqual(SpaceHUDSettings.Duration.short.seconds, 0.5)
        XCTAssertEqual(SpaceHUDSettings.Duration.normal.seconds, 0.8)
        XCTAssertEqual(SpaceHUDSettings.Duration.long.seconds, 1.5)
    }
}
