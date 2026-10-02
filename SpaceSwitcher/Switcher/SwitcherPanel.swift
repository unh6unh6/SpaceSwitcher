import AppKit
import SwiftUI

/// Floating, non-activating panel centered on the main display (SPEC §3.2).
final class SwitcherPanel: NSPanel {
    private let hosting: NSHostingView<SwitcherView>

    init(model: SwitcherViewModel) {
        hosting = NSHostingView(rootView: SwitcherView(model: model))
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .popUpMenu  // above fullscreen apps
        // Appear on whatever Space is active, including fullscreen ones, without making macOS switch Spaces.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: effect.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        contentView = effect
    }

    /// Needed so the inline rename field can receive typing.
    override var canBecomeKey: Bool { true }

    /// Re-centers after the content changed size (memo preview appearing for an edit, etc.).
    func recenter() {
        guard isVisible else { return }
        DispatchQueue.main.async { [weak self] in self?.present() }  // after SwiftUI's layout pass
    }

    func present() {
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.fittingSize
        // screens[0] is the display with the menu bar, i.e. the "main display" in System Settings.
        let screen = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame ?? .zero
        setFrame(NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2,
                        width: size.width, height: size.height), display: true)
        orderFrontRegardless()
    }

    /// Hides the panel and runs `body` once the window server has actually taken it off screen.
    ///
    /// `orderOut` returns immediately but the window lingers ~40 ms (measured with CGWindowList, #8).
    /// A Space switch started in that gap animates with the panel still in the picture, and because the
    /// panel joins all Spaces it rides along through every step of the Ctrl+←/→ fallback.
    func hide(then body: @escaping () -> Void) {
        orderOut(nil)
        CATransaction.flush()
        let deadline = Date().addingTimeInterval(0.2)  // never hold the switch back longer than this
        func poll() {
            if !isOnScreenForWindowServer || Date() > deadline {
                body()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.005, execute: poll)
            }
        }
        poll()
    }

    private var isOnScreenForWindowServer: Bool {
        guard windowNumber > 0,
              let info = CGWindowListCopyWindowInfo(.optionIncludingWindow, CGWindowID(windowNumber)) as? [[String: Any]],
              let window = info.first else { return false }
        return window[kCGWindowIsOnscreen as String] as? Bool ?? false
    }
}
