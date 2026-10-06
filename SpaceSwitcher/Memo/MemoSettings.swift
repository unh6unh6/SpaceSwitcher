import CoreGraphics
import Foundation

/// Preferences for desktop memos (#18) and the Option+E memo preview (#20). Pure; UserDefaults-backed.
struct MemoSettings: Equatable {
    enum Corner: String, CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight

        /// Where a window of `size` sits in this corner of `screen` (AppKit coordinates: y grows upward).
        func origin(for size: CGSize, in screen: CGRect) -> CGPoint {
            let m = MemoSettings.margin
            let left = screen.minX + m, right = screen.maxX - size.width - m
            let bottom = screen.minY + m, top = screen.maxY - size.height - m
            switch self {
            case .topLeft: return CGPoint(x: left, y: top)
            case .topRight: return CGPoint(x: right, y: top)
            case .bottomLeft: return CGPoint(x: left, y: bottom)
            case .bottomRight: return CGPoint(x: right, y: bottom)
            }
        }
    }

    static let margin: CGFloat = 16
    static let minOpacity = 0.3
    static let defaultSize = CGSize(width: 320, height: 220)

    /// Where the overlay sits on one desktop (#24): its own frame and collapse state.
    struct Layout: Codable, Equatable {
        var frame: CGRect?
        var collapsed = false
    }

    var overlayEnabled = false
    var previewEnabled = true
    var opacity = 0.85
    var corner = Corner.topRight
    /// Where the user dragged/resized the memo window; nil = default size in `corner`.
    var frame: CGRect?
    var collapsed = false
    var hideWhenEmpty = false
    /// Memo folder; nil = `MemoStore.defaultDirectory`.
    var directoryPath: String?
    /// Per-desktop layouts keyed by `Space.id` (#24). `frame`/`collapsed` above are the shared fallback,
    /// used by desktops that have none yet and by fullscreen app Spaces.
    var layouts: [String: Layout] = [:]

    func layout(for spaceID: String?) -> Layout {
        spaceID.flatMap { layouts[$0] } ?? Layout(frame: frame, collapsed: collapsed)
    }

    mutating func setLayout(_ layout: Layout, for spaceID: String?) {
        if let spaceID {
            layouts[spaceID] = layout
        } else {
            frame = layout.frame
            collapsed = layout.collapsed
        }
    }

    /// A corner pick in Settings moves every desktop's memo to that corner; collapse states stay.
    mutating func resetPositions() {
        frame = nil
        for id in layouts.keys { layouts[id]?.frame = nil }
    }

    mutating func pruneLayouts(keeping ids: Set<String>) {
        layouts = layouts.filter { ids.contains($0.key) }
    }

    static let didChange = Notification.Name("MemoSettings.didChange")

    private enum Key {
        static let overlay = "memoOverlayEnabled", preview = "memoPreviewEnabled", opacity = "memoOpacity"
        static let corner = "memoCorner", frame = "memoFrame", collapsed = "memoCollapsed"
        static let hideWhenEmpty = "memoHideWhenEmpty", directory = "memoDirectory", layouts = "memoLayouts"
    }

    static func load(from defaults: UserDefaults = .standard) -> MemoSettings {
        var s = MemoSettings()
        if defaults.object(forKey: Key.overlay) != nil { s.overlayEnabled = defaults.bool(forKey: Key.overlay) }
        if defaults.object(forKey: Key.preview) != nil { s.previewEnabled = defaults.bool(forKey: Key.preview) }
        if defaults.object(forKey: Key.opacity) != nil { s.opacity = clampOpacity(defaults.double(forKey: Key.opacity)) }
        if let raw = defaults.string(forKey: Key.corner), let corner = Corner(rawValue: raw) { s.corner = corner }
        if let raw = defaults.string(forKey: Key.frame) { s.frame = parseFrame(raw) }
        s.collapsed = defaults.bool(forKey: Key.collapsed)
        s.hideWhenEmpty = defaults.bool(forKey: Key.hideWhenEmpty)
        s.directoryPath = defaults.string(forKey: Key.directory)
        if let data = defaults.data(forKey: Key.layouts),
           let layouts = try? JSONDecoder().decode([String: Layout].self, from: data) {
            s.layouts = layouts
        }
        return s
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(overlayEnabled, forKey: Key.overlay)
        defaults.set(previewEnabled, forKey: Key.preview)
        defaults.set(Self.clampOpacity(opacity), forKey: Key.opacity)
        defaults.set(corner.rawValue, forKey: Key.corner)
        if let frame {
            defaults.set("\(frame.origin.x),\(frame.origin.y),\(frame.width),\(frame.height)", forKey: Key.frame)
        } else {
            defaults.removeObject(forKey: Key.frame)
        }
        defaults.set(collapsed, forKey: Key.collapsed)
        defaults.set(hideWhenEmpty, forKey: Key.hideWhenEmpty)
        if let directoryPath { defaults.set(directoryPath, forKey: Key.directory) } else { defaults.removeObject(forKey: Key.directory) }
        defaults.set(try? JSONEncoder().encode(layouts), forKey: Key.layouts)
        NotificationCenter.default.post(name: Self.didChange, object: nil)
    }

    /// Keeps a saved frame fully on `screen` (e.g. after unplugging a bigger monitor).
    static func clamp(_ frame: CGRect, to screen: CGRect) -> CGRect {
        let width = min(frame.width, screen.width), height = min(frame.height, screen.height)
        let x = min(max(frame.minX, screen.minX), screen.maxX - width)
        let y = min(max(frame.minY, screen.minY), screen.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private static func clampOpacity(_ value: Double) -> Double {
        min(max(value, minOpacity), 1)
    }

    private static func parseFrame(_ raw: String) -> CGRect? {
        let parts = raw.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4, parts[2] > 0, parts[3] > 0 else { return nil }
        return CGRect(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }
}
