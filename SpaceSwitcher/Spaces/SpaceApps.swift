import Foundation

/// Which apps have windows on which desktop, for the icons in the switcher list (#14). Pure.
enum SpaceApps {
    struct Window: Equatable {
        let id: Int
        let pid: Int32
        let appName: String
        let layer: Int
        let width: Double
        let height: Double
    }

    struct App: Equatable {
        let pid: Int32
        let name: String
        let windowCount: Int
    }

    /// Normal document windows live on layer 0; anything else is a menu, panel, overlay, etc.
    private static let documentLayer = 0
    /// Smaller windows are helpers (e.g. invisible 1×1 or tiny status windows), not something to show.
    private static let minimumSide = 50.0

    /// Apps per Space ID, most windows first, then by name.
    /// - Parameters:
    ///   - spacesOf: Space IDs a window is on (CGSCopySpacesForWindows).
    ///   - isRegularApp: whether the pid is a normal Dock app (filters WindowManager, Dock, agents…).
    static func group(_ windows: [Window], spacesOf: (Int) -> [Int], isRegularApp: (Int32) -> Bool) -> [Int: [App]] {
        var counts: [Int: [Int32: (name: String, count: Int)]] = [:]
        for window in windows where window.layer == documentLayer
            && window.width >= minimumSide && window.height >= minimumSide && isRegularApp(window.pid) {
            for space in spacesOf(window.id) {
                counts[space, default: [:]][window.pid, default: (window.appName, 0)].count += 1
            }
        }
        return counts.mapValues { apps in
            apps.map { App(pid: $0.key, name: $0.value.name, windowCount: $0.value.count) }
                .sorted { ($0.windowCount, $1.name) > ($1.windowCount, $0.name) }
        }
    }

    /// The first `limit` apps plus how many didn't fit ("+N").
    static func visible(_ apps: [App], limit: Int) -> (apps: [App], overflow: Int) {
        (Array(apps.prefix(limit)), max(0, apps.count - limit))
    }

    // MARK: setting (Settings → General)

    private static let showIconsKey = "switcherShowAppIcons"

    static func showIcons(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: showIconsKey) == nil ? true : defaults.bool(forKey: showIconsKey)
    }

    static func setShowIcons(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: showIconsKey)
    }
}
