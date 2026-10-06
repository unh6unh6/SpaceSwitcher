import AppKit

/// Applies a `MemoSettings.Background` to a panel built on an `NSVisualEffectView` (the memo
/// overlay): the HUD material for `standard`, a solid color otherwise, with the
/// window appearance set so text stays readable on it.
enum PanelBackground {
    private static let tintID = NSUserInterfaceItemIdentifier("SpaceSwitcher.backgroundTint")

    static func apply(_ background: MemoSettings.Background, to effect: NSVisualEffectView, in window: NSWindow) {
        let tint = effect.subviews.first { $0.identifier == tintID } ?? {
            let view = NSView()
            view.identifier = tintID
            view.wantsLayer = true
            view.translatesAutoresizingMaskIntoConstraints = false
            effect.addSubview(view, positioned: .below, relativeTo: effect.subviews.first)
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
                view.topAnchor.constraint(equalTo: effect.topAnchor),
                view.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
            ])
            return view
        }()
        if let rgb = background.rgb {
            tint.layer?.backgroundColor = NSColor(srgbRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1).cgColor
            tint.isHidden = false
        } else {
            tint.isHidden = true
        }
        switch background.isDark {
        case .some(true): window.appearance = NSAppearance(named: .darkAqua)
        case .some(false): window.appearance = NSAppearance(named: .aqua)
        case .none: window.appearance = nil
        }
    }
}
