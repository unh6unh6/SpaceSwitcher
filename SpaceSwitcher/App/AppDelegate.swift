import AppKit
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let names = NameStore()
    private lazy var memos = MemoStore(directory: MemoSettings.load().directoryPath.map { URL(fileURLWithPath: $0) }
                                                 ?? MemoStore.defaultDirectory)
    private let permissions = PermissionMonitor()
    private lazy var permissionsWindow = PermissionsWindowController(monitor: permissions)
    private lazy var switcher = SwitcherController(names: names, memos: memos)
    private var hud: SpaceHUDController?
    private lazy var settingsWindow = SettingsWindowController(model: SettingsModel(
        names: names, memos: memos, permissions: permissions,
        setSwitcherSuspended: { [weak self] in self?.switcher.setSuspended($0) }))
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
        migrateLegacyDescriptions()
        hud = SpaceHUDController(names: names)

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

    /// #17 builds kept descriptions in names.json; they are memo files now (#18).
    private func migrateLegacyDescriptions() {
        let legacy = names.legacyDescriptions
        guard !legacy.isEmpty else { return }
        let spaces = SpaceProvider.spaces()
        memos.importLegacy(legacy) { id in
            spaces.first { $0.id == id }.map(names.displayName) ?? names.name(for: id) ?? "데스크탑"
        }
        names.clearLegacyDescriptions()
    }
}
