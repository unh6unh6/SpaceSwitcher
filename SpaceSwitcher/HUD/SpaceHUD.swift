import AppKit

/// Shows the desktop name briefly after every Space change, however it happened (#13).
final class SpaceHUDController {
    private let names: NameStore
    private var settings = SpaceHUDSettings.load()
    private lazy var panel = SpaceHUDPanel()
    private var hideWork: DispatchWorkItem?

    init(names: NameStore) {
        self.names = names
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.show()
        }
        NotificationCenter.default.addObserver(forName: SpaceHUDSettings.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.settings = SpaceHUDSettings.load()
        }
    }

    private func show() {
        hideWork?.cancel()
        let current = SpaceProvider.spaces().first(where: \.isCurrent)
        guard settings.isEnabled,
              let text = SpaceHUDContent.text(for: current, name: current.flatMap { names.name(for: $0.id) }) else {
            panel.fadeOut()  // e.g. moved onto a fullscreen app: drop a HUD still showing for the previous desktop
            return
        }
        panel.show(text, at: settings.position)
        let work = DispatchWorkItem { [weak self] in self?.panel.fadeOut() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.duration.seconds, execute: work)
    }
}

/// Click-through overlay on every Space, including over fullscreen apps.
final class SpaceHUDPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    /// Bumped on every show so a fade-out that finishes late can't hide a newer HUD.
    private var generation = 0

    init() {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 34, weight: .semibold)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 36),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -36),
            label.topAnchor.constraint(equalTo: effect.topAnchor, constant: 22),
            label.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -22),
        ])
        contentView = effect
    }

    func show(_ text: String, at position: SpaceHUDSettings.Position) {
        generation += 1
        label.stringValue = text
        let content = contentView!
        content.layoutSubtreeIfNeeded()
        let screen = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame ?? .zero
        let size = NSSize(width: min(content.fittingSize.width, screen.width * 0.8), height: content.fittingSize.height)
        let y = position == .center ? screen.midY - size.height / 2 : screen.maxY - size.height - 60
        setFrame(NSRect(x: screen.midX - size.width / 2, y: y, width: size.width, height: size.height), display: true)

        if !isVisible { alphaValue = 0 }
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            animator().alphaValue = 1
        }
    }

    func fadeOut() {
        guard isVisible else { return }
        let shownGeneration = generation
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, generation == shownGeneration else { return }
            orderOut(nil)
        })
    }
}
