import Foundation

/// What the "you are here" overlay says after a desktop switch (#13).
enum SpaceHUDContent {
    /// `nil` when the active Space isn't a regular desktop (e.g. a fullscreen app): nothing to show.
    static func text(for space: Space?, name: String?) -> String? {
        guard let space else { return nil }
        guard let name else { return "데스크탑 \(space.index)" }
        return "\(space.index) · \(name)"
    }
}

/// User preferences for the overlay, stored in UserDefaults.
struct SpaceHUDSettings: Equatable {
    enum Duration: String, CaseIterable {
        case short, normal, long

        var seconds: TimeInterval {
            switch self {
            case .short: return 0.5
            case .normal: return 0.8
            case .long: return 1.5
            }
        }
    }

    enum Position: String, CaseIterable {
        case center, top
    }

    var isEnabled = true
    var duration = Duration.normal
    var position = Position.center

    static let didChange = Notification.Name("SpaceHUDSettings.didChange")
    private static let enabledKey = "hudEnabled"
    private static let durationKey = "hudDuration"
    private static let positionKey = "hudPosition"

    static func load(from defaults: UserDefaults = .standard) -> SpaceHUDSettings {
        var settings = SpaceHUDSettings()
        if defaults.object(forKey: enabledKey) != nil { settings.isEnabled = defaults.bool(forKey: enabledKey) }
        if let raw = defaults.string(forKey: durationKey), let value = Duration(rawValue: raw) { settings.duration = value }
        if let raw = defaults.string(forKey: positionKey), let value = Position(rawValue: raw) { settings.position = value }
        return settings
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: Self.enabledKey)
        defaults.set(duration.rawValue, forKey: Self.durationKey)
        defaults.set(position.rawValue, forKey: Self.positionKey)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }
}
