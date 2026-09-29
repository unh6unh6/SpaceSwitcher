import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let names = NameStore()
    private let permissions = PermissionMonitor()
    private lazy var permissionsWindow = PermissionsWindowController(monitor: permissions)
    private var statusItemController: StatusItemController?

    private static let onboardedKey = "didShowOnboarding"

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(names: names, permissions: permissions) { [weak self] in
            self?.permissionsWindow.show()
        }

        // SPEC §3.7: show on first launch, or whenever Accessibility is missing.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.onboardedKey) || !permissions.isTrusted {
            defaults.set(true, forKey: Self.onboardedKey)
            permissionsWindow.show()
        }
    }
}
