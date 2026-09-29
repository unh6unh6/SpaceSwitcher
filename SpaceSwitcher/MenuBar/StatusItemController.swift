import AppKit
import Combine

/// Menu bar item: shows the current desktop and lists all desktops.
final class StatusItemController: NSObject, NSMenuDelegate {
    /// Longer names are cut with "…" in the menu bar only (SPEC §3.5); menus show the full name.
    private static let maxTitleLength = 20

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let names: NameStore
    private let permissions: PermissionMonitor
    private let showPermissions: () -> Void
    private let showSettings: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(names: NameStore, permissions: PermissionMonitor,
         showPermissions: @escaping () -> Void, showSettings: @escaping () -> Void) {
        self.names = names
        self.permissions = permissions
        self.showPermissions = showPermissions
        self.showSettings = showSettings
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshTitle()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshTitle),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refreshTitle), name: NameStore.didChange, object: names)
        permissions.$isTrusted
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refreshTitle() } }
            .store(in: &cancellables)
    }

    @objc private func refreshTitle() {
        let current = SpaceProvider.spaces().first(where: \.isCurrent)
        var name = current.map(names.displayName) ?? "전체화면"
        if name.count > Self.maxTitleLength {
            name = String(name.prefix(Self.maxTitleLength - 1)) + "…"
        }
        statusItem.button?.title = permissions.isTrusted ? name : "⚠︎ \(name)"
    }

    // Rebuilt on every open because desktop add/remove/reorder has no notification.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let spaces = SpaceProvider.spaces()

        if !permissions.isTrusted {
            menu.addItem(item("⚠︎ 손쉬운 사용 권한 필요 — 설정…", #selector(openPermissions)))
            menu.addItem(.separator())
        }
        for space in spaces {
            let entry = item("", #selector(selectSpace(_:)))
            entry.attributedTitle = title(for: space)
            entry.representedObject = space.id
            entry.state = space.isCurrent ? .on : .off
            menu.addItem(entry)
        }
        menu.addItem(.separator())
        let rename = item("현재 데스크탑 이름 변경…", #selector(renameCurrent))
        rename.isEnabled = spaces.contains(where: \.isCurrent)  // not on fullscreen Spaces
        menu.addItem(rename)
        let settings = item("설정…", #selector(openSettings))
        settings.keyEquivalent = ","
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "SpaceSwitcher 종료",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        refreshTitle()
    }

    /// "1  업무", or a dimmed "3  데스크탑 3" when unnamed.
    private func title(for space: Space) -> NSAttributedString {
        let text = "\(space.index)  \(names.displayName(for: space))"
        let named = names.name(for: space.id) != nil
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.menuFont(ofSize: 0),
            .foregroundColor: named ? NSColor.labelColor : NSColor.secondaryLabelColor,
        ])
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func selectSpace(_ sender: NSMenuItem) {
        // Re-resolve by id: the list may have changed since the menu was built.
        guard let id = sender.representedObject as? String,
              let target = SpaceProvider.spaces().first(where: { $0.id == id }) else { return }
        if !permissions.isTrusted {
            showPermissions()
            return
        }
        SpaceSwitcherService.switchTo(target)
    }

    @objc private func renameCurrent() {
        guard let current = SpaceProvider.spaces().first(where: \.isCurrent),
              let entered = RenamePrompt.run(for: current, currentName: names.name(for: current.id)) else { return }
        names.setName(entered, for: current.id)
    }

    @objc private func openPermissions() {
        showPermissions()
    }

    @objc private func openSettings() {
        showSettings()
    }
}
