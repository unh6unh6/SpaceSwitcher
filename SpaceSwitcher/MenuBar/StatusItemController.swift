import AppKit
import Combine

/// Menu bar item: shows the current desktop and lists all desktops.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let permissions: PermissionMonitor
    private let showPermissions: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(permissions: PermissionMonitor, showPermissions: @escaping () -> Void) {
        self.permissions = permissions
        self.showPermissions = showPermissions
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        refreshTitle()

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(activeSpaceDidChange),
            name: NSWorkspace.activeSpaceDidChangeNotification, object: nil)
        permissions.$isTrusted
            .removeDuplicates()
            .sink { [weak self] _ in DispatchQueue.main.async { self?.refreshTitle() } }
            .store(in: &cancellables)
    }

    @objc private func activeSpaceDidChange() {
        refreshTitle()
    }

    private func refreshTitle() {
        let current = SpaceProvider.spaces().first(where: \.isCurrent)
        let name = current.map(Self.displayName) ?? "전체화면"
        statusItem.button?.title = permissions.isTrusted ? name : "⚠︎ \(name)"
    }

    static func displayName(_ space: Space) -> String {
        "데스크탑 \(space.index)"
    }

    // Rebuilt on every open because desktop add/remove/reorder has no notification.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if !permissions.isTrusted {
            let warning = NSMenuItem(title: "⚠︎ 손쉬운 사용 권한 필요 — 설정…",
                                     action: #selector(openPermissions), keyEquivalent: "")
            warning.target = self
            menu.addItem(warning)
            menu.addItem(.separator())
        }
        for space in SpaceProvider.spaces() {
            let item = NSMenuItem(title: "\(space.index)  \(Self.displayName(space))",
                                  action: #selector(selectSpace(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = space.id
            item.state = space.isCurrent ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "권한 및 단축키 확인…", action: #selector(openPermissions), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(NSMenuItem(title: "SpaceSwitcher 종료",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        refreshTitle()
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

    @objc private func openPermissions() {
        showPermissions()
    }
}
