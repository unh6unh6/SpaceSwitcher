import Foundation

/// The menu bar text for the current desktop, in the style chosen in Settings (#15). Pure.
enum MenuBarTitle {
    enum Style: String, CaseIterable {
        case name           // 업무
        case numberAndName  // 2 업무
        case dots           // ○ ● ○ ○
        case dotsAndName    // ○ ● ○ ○ 업무
        case number         // 2
    }

    /// Beyond this many desktops the dots turn into "2/12".
    static let maxDots = 9
    static let lengthOptions = [10, 20, 30]

    /// - Parameter currentIndex: 1-based desktop number, nil on a fullscreen app Space.
    static func text(style: Style, currentIndex: Int?, desktopCount: Int, name: String?, maxLength: Int) -> String {
        let label = currentIndex.map { truncated(name ?? "데스크탑 \($0)", to: maxLength) } ?? "전체화면"
        switch style {
        case .name:
            return label
        case .numberAndName:
            return currentIndex.map { "\($0) \(label)" } ?? label
        case .number:
            return currentIndex.map(String.init) ?? "–"
        case .dots:
            return indicator(currentIndex, desktopCount)
        case .dotsAndName:
            let dots = indicator(currentIndex, desktopCount)
            return currentIndex == nil ? dots : "\(dots) \(label)"
        }
    }

    private static func indicator(_ current: Int?, _ count: Int) -> String {
        if count > maxDots, let current { return "\(current)/\(count)" }
        return (1...max(count, 1)).map { $0 == current ? "●" : "○" }.joined(separator: " ")
    }

    private static func truncated(_ text: String, to maxLength: Int) -> String {
        text.count > maxLength ? String(text.prefix(maxLength - 1)) + "…" : text
    }

    struct Settings: Equatable {
        var style = Style.name
        var maxLength = 20

        static let didChange = Notification.Name("MenuBarTitle.Settings.didChange")
        private static let styleKey = "menuBarStyle"
        private static let lengthKey = "menuBarMaxLength"

        static func load(from defaults: UserDefaults = .standard) -> Settings {
            var settings = Settings()
            if let raw = defaults.string(forKey: styleKey), let style = Style(rawValue: raw) { settings.style = style }
            let length = defaults.integer(forKey: lengthKey)
            if MenuBarTitle.lengthOptions.contains(length) { settings.maxLength = length }
            return settings
        }

        func save(to defaults: UserDefaults = .standard) {
            defaults.set(style.rawValue, forKey: Self.styleKey)
            defaults.set(maxLength, forKey: Self.lengthKey)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }
}
