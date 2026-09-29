import AppKit

/// Menu bar item: shows the current desktop and lists all desktops.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()

    override init() {
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshTitle()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
    }

    @objc private func activeSpaceDidChange() {
        refreshTitle()
    }

    private func refreshTitle() {
        let current = SpaceProvider.spaces().first(where: \.isCurrent)
        statusItem.button?.title = current.map(Self.displayName) ?? "전체화면"
    }

    static func displayName(_ space: Space) -> String {
        "데스크탑 \(space.index)"
    }

    // Rebuilt on every open because desktop add/remove/reorder has no notification.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        for space in SpaceProvider.spaces() {
            let item = NSMenuItem(title: "\(space.index)  \(Self.displayName(space))", action: nil, keyEquivalent: "")
            item.state = space.isCurrent ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "SpaceSwitcher 종료",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        refreshTitle()
    }
}
