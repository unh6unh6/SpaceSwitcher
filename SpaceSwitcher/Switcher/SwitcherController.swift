import AppKit

/// Wires the event tap, state machine, panel and stores together.
///
/// Keys in Sticky stay on the event tap rather than making the panel the key window:
/// becoming key requires activating the app, which steals focus from the user's app and
/// can pull macOS onto another Space. Only inline rename activates, because a text field needs it.
final class SwitcherController {
    var shortcut = Shortcut.default

    private let names: NameStore
    private let tap = EventTap()
    private let model = SwitcherViewModel()
    private lazy var panel = SwitcherPanel(model: model)
    private var machine: SwitcherStateMachine!
    private var mru = MRUTracker()
    /// Desktops as they were when the panel opened; rows index into this.
    private var spaces: [Space] = []
    private var clickMonitor: Any?
    private var activatedForRename = false

    init(names: NameStore) {
        self.names = names
        machine = SwitcherStateMachine { [unowned self] in
            spaces = SpaceProvider.spaces()
            return (count: spaces.count, initial: mru.initialSelection(InitialSelection.stored, in: spaces))
        }

        tap.onKeyDown = { [weak self] key in self?.handleKey(key) ?? false }
        tap.onFlagsChanged = { [weak self] previous, current in
            guard let self, KeyMapper.modifierReleased(previous: previous, current: current, shortcut: shortcut)
            else { return }
            send(.modifierReleased)
        }

        model.onClick = { [weak self] row in self?.send(.select(row)) }
        model.onDoubleClick = { [weak self] row in
            self?.send(.highlight(row))
            self?.send(.beginRename)
        }
        model.onCommitRename = { [weak self] text in self?.commitRename(text) }
        model.onCancelRename = { [weak self] in self?.send(.endRename) }

        recordCurrentSpace()
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recordCurrentSpace()
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.tap.ensureEnabled()
        }
    }

    /// Needs Accessibility; returns false until it is granted.
    @discardableResult
    func start() -> Bool {
        tap.start()
    }

    // MARK: input

    /// Runs inside the tap callback on the main thread: decide synchronously, render asynchronously.
    private func handleKey(_ key: EventTap.KeyEvent) -> Bool {
        let decision = KeyMapper.map(keyCode: key.keyCode, flags: key.flags, isAutorepeat: key.isAutorepeat,
                                     shortcut: shortcut, capturing: machine.isCapturingKeys)
        switch decision {
        case .pass:
            return false
        case .consume(let event):
            if let event { send(event) }
            return true
        }
    }

    private func send(_ event: SwitcherStateMachine.Event) {
        guard let action = machine.handle(event) else { return }
        DispatchQueue.main.async { [weak self] in self?.perform(action) }
    }

    // MARK: output

    private func perform(_ action: SwitcherStateMachine.Action) {
        switch action {
        case .show(let selection):
            reloadRows()
            model.selection = selection
            model.renamingRow = nil
            panel.present()
            startClickMonitor()
        case .select(let row):
            if model.renamingRow != nil { finishRenameUI() }
            model.selection = row
        case .hide:
            close()
        case .switchTo(let row):
            let target = spaces.indices.contains(row) ? spaces[row] : nil
            close()
            if let target { SpaceSwitcherService.switchTo(target) }
        case .rename(let row):
            guard spaces.indices.contains(row) else { return }
            model.selection = row
            model.draft = names.name(for: spaces[row].id) ?? ""
            model.renamingRow = row
            activatedForRename = true
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKey()
        }
    }

    private func commitRename(_ text: String) {
        guard let row = model.renamingRow, spaces.indices.contains(row) else { return }
        names.setName(text, for: spaces[row].id)
        reloadRows()
        send(.endRename)
    }

    private func finishRenameUI() {
        model.renamingRow = nil
        panel.resignKey()
        returnFocus()
    }

    private func close() {
        model.renamingRow = nil
        panel.orderOut(nil)
        stopClickMonitor()
        returnFocus()
    }

    /// Give the keyboard back to the app the user was in after an inline rename.
    private func returnFocus() {
        guard activatedForRename else { return }
        activatedForRename = false
        NSApp.hide(nil)
    }

    private func reloadRows() {
        model.rows = spaces.map { space in
            SwitcherViewModel.Row(id: space.id, number: space.index, title: names.displayName(for: space),
                                  isNamed: names.name(for: space.id) != nil, isCurrent: space.isCurrent)
        }
    }

    private func recordCurrentSpace() {
        if let current = SpaceProvider.spaces().first(where: \.isCurrent) { mru.visit(current.id) }
    }

    // Global monitors only see events aimed at other apps, i.e. clicks outside the panel.
    private func startClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.send(.clickOutside)
        }
    }

    private func stopClickMonitor() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        clickMonitor = nil
    }
}
