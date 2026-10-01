import XCTest
@testable import SpaceSwitcher

final class SpaceAppsTests: XCTestCase {
    private func window(_ id: Int, pid: Int32, _ name: String, layer: Int = 0, size: Double = 800) -> SpaceApps.Window {
        SpaceApps.Window(id: id, pid: pid, appName: name, layer: layer, width: size, height: size)
    }

    func testGroupsWindowsByDesktopAndApp() {
        let windows = [window(1, pid: 10, "Chrome"), window(2, pid: 10, "Chrome"), window(3, pid: 20, "Slack")]
        let spaces: [Int: [Int]] = [1: [100], 2: [100], 3: [200]]
        let result = SpaceApps.group(windows, spacesOf: { spaces[$0] ?? [] }, isRegularApp: { _ in true })
        XCTAssertEqual(result[100], [SpaceApps.App(pid: 10, name: "Chrome", windowCount: 2)])
        XCTAssertEqual(result[200], [SpaceApps.App(pid: 20, name: "Slack", windowCount: 1)])
    }

    func testSortsByWindowCountThenName() {
        let windows = [window(1, pid: 30, "Notion"), window(2, pid: 20, "Slack"),
                       window(3, pid: 10, "Chrome"), window(4, pid: 10, "Chrome")]
        let result = SpaceApps.group(windows, spacesOf: { _ in [100] }, isRegularApp: { _ in true })
        XCTAssertEqual(result[100]?.map(\.name), ["Chrome", "Notion", "Slack"])
    }

    // Menus, tooltips, the Dock, WindowManager and tiny helper windows aren't "apps on this desktop".
    func testFiltersNonDocumentWindows() {
        let windows = [
            window(1, pid: 10, "Chrome"),
            window(2, pid: 10, "Chrome", layer: 25),             // floating / menu bar level
            window(3, pid: 40, "WindowManager"),                  // not a regular app
            window(4, pid: 20, "Slack", size: 30),                // tiny helper window
        ]
        let result = SpaceApps.group(windows, spacesOf: { _ in [100] }, isRegularApp: { $0 != 40 })
        XCTAssertEqual(result[100], [SpaceApps.App(pid: 10, name: "Chrome", windowCount: 1)])
    }

    // A window can be on every desktop ("Assign to: All Desktops"); it counts for each.
    func testWindowOnSeveralSpacesCountsForEach() {
        let result = SpaceApps.group([window(1, pid: 10, "Stickies")], spacesOf: { _ in [100, 200] },
                                     isRegularApp: { _ in true })
        XCTAssertEqual(result[100]?.count, 1)
        XCTAssertEqual(result[200]?.count, 1)
    }

    func testDesktopWithoutWindowsIsAbsent() {
        let result = SpaceApps.group([], spacesOf: { _ in [] }, isRegularApp: { _ in true })
        XCTAssertNil(result[100])
    }

    // MARK: display

    func testVisibleAndOverflow() {
        let apps = (1...7).map { SpaceApps.App(pid: Int32($0), name: "A\($0)", windowCount: 1) }
        let shown = SpaceApps.visible(apps, limit: 5)
        XCTAssertEqual(shown.apps.count, 5)
        XCTAssertEqual(shown.overflow, 2)
        XCTAssertEqual(SpaceApps.visible(Array(apps.prefix(3)), limit: 5).overflow, 0)
    }

    // MARK: setting

    func testShowAppIconsSettingDefaultsOnAndRoundTrips() {
        let suite = "SpaceSwitcherTests.SpaceApps"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        XCTAssertTrue(SpaceApps.showIcons(in: defaults))
        SpaceApps.setShowIcons(false, in: defaults)
        XCTAssertFalse(SpaceApps.showIcons(in: defaults))
    }
}
