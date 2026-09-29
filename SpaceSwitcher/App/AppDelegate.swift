import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let names = NameStore()
    private let permissions = PermissionMonitor()
    private lazy var permissionsWindow = PermissionsWindowController(monitor: permissions)
    private lazy var switcher = SwitcherController(names: names)
    private lazy var settingsWindow = SettingsWindowController(model: SettingsModel(
        names: names, permissions: permissions,
        setSwitcherSuspended: { [weak self] in self?.switcher.isSuspended = $0 }))
    private var statusItemController: StatusItemController?
    private var cancellables = Set<AnyCancellable>()

    private static let onboardedKey = "didShowOnboarding"

    /// Unit tests are hosted in the app; don't grab the keyboard or open windows while they run.
    private var isRunningTests: Bool { NSClassFromString("XCTestCase") != nil }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItemController = StatusItemController(
            names: names, permissions: permissions,
            showPermissions: { [weak self] in self?.permissionsWindow.show() },
            showSettings: { [weak self] in self?.settingsWindow.show() })
        guard !isRunningTests else { return }

        // The event tap can only be created once Accessibility is granted; retry when it is.
        permissions.$isTrusted
            .filter { $0 }
            .sink { [weak self] _ in DispatchQueue.main.async { self?.switcher.start() } }
            .store(in: &cancellables)

        // SPEC §3.7: show on first launch, or whenever Accessibility is missing.
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.onboardedKey) || !permissions.isTrusted {
            defaults.set(true, forKey: Self.onboardedKey)
            permissionsWindow.show()
        }
    }
}
