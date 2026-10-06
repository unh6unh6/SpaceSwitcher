import AppKit
import SwiftUI

/// The always-on-top memo for the current desktop (#18). One panel on every Space; its content
/// follows the active desktop. Editing borrows the keyboard and gives it back afterwards.
final class MemoOverlayController: NSObject, NSWindowDelegate {
    private let names: NameStore
    private let memos: MemoStore
    private let model = MemoOverlayModel()
    private lazy var panel = MemoOverlayPanel(model: model, delegate: self)
    private let focus = FocusReturner()
    private var settings = MemoSettings.load()
    private var currentSpace: Space?
    /// The desktop whose memo is being edited (#26). The overlay follows the active desktop, so the
    /// current desktop can change mid-edit; saving must go here, not to `currentSpace`.
    private var editingSpace: Space?
    /// Unsaved edits of desktops the user moved away from; they reopen on return (#26).
    private var drafts = MemoDrafts()
    /// Reading position per desktop (#25), and the desktop whose memo the panel shows now.
    private var scroll = MemoScrollMemory()
    private var scrollShownFor: String?
    /// Frame changes we make ourselves must not be saved back as "the user moved it".
    private var applyingFrame = false
    /// The desktop whose layout the panel currently shows (#24); nil = shared layout (fullscreen Space).
    private var placedFor: String?? = .none

    init(names: NameStore, memos: MemoStore) {
        self.names = names
        self.memos = memos
        super.init()
        model.onEdit = { [weak self] in self?.beginEdit() }
        model.onSave = { [weak self] text in self?.save(text) }
        model.onCancel = { [weak self] in self?.endEdit() }
        model.onToggleCollapse = { [weak self] in self?.toggleCollapse() }
        model.onHover = { [weak self] inside in self?.applyOpacity(hovering: inside) }
        model.onToggleTask = { [weak self] line in self?.toggleTask(line) }

        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        for name in [MemoStore.didChange, NameStore.didChange] {
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() }
        }
        NotificationCenter.default.addObserver(forName: MemoSettings.didChange, object: nil, queue: .main) { [weak self] _ in
            self?.settingsChanged()
        }
        refresh()
    }

    // MARK: content

    private func refresh() {
        let spaces = SpaceProvider.spaces()
        currentSpace = spaces.first(where: \.isCurrent)
        if let editingSpace {
            if editingSpace.id == currentSpace?.id {
                // Same desktop (e.g. the file changed on disk): never yank text out from under the editor.
                model.title = MemoEditTarget.editingTitle(names.displayName(for: editingSpace))
                return
            }
            // Moved away mid-edit (#26): park the text with its desktop and show this one normally.
            drafts.park(model.draft, for: editingSpace.id)
            self.editingSpace = nil
            model.isEditing = false
            focus.release()
        }
        for text in drafts.takeOrphans(keeping: Set(spaces.map(\.id))) { keepUnsavedText(text) }
        scroll.set(model.scrollLine, for: scrollShownFor)
        model.title = currentSpace.map(names.displayName) ?? "전체화면"
        model.memo = currentSpace.flatMap { memos.memo(for: $0.id) }
        model.canEdit = currentSpace != nil
        scrollShownFor = currentSpace?.id
        model.scrollKey = currentSpace?.id ?? ""
        model.scrollLine = scroll.position(for: scrollShownFor,
                                           blockCount: model.memo.map { MarkdownBlocks.parse($0).count } ?? 0)
        if placedFor != .some(currentSpace?.id), panel.isVisible { relocate() }
        if let space = currentSpace, let draft = drafts.take(for: space.id) {
            resumeEdit(space, draft: draft)
        }
        updateVisibility()
    }

    /// New desktop, new layout (#24): fade out, move, fade back in, so the panel doesn't visibly jump
    /// from the previous desktop's spot.
    private func relocate() {
        panel.alphaValue = 0
        placePanel()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = settings.opacity
        }
    }

    private func updateVisibility() {
        let empty = model.memo == nil
        let shouldShow = settings.overlayEnabled && !(settings.hideWhenEmpty && empty && !model.isEditing)
        if shouldShow {
            if !panel.isVisible { placePanel() }
            applyOpacity(hovering: false)
            panel.orderFrontRegardless()
        } else {
            panel.orderOut(nil)
        }
    }

    // MARK: editing

    private func beginEdit() {
        guard let space = currentSpace else { return }
        if settings.layout(for: space.id).collapsed { toggleCollapse() }
        resumeEdit(space, draft: model.memo ?? "")
    }

    private func resumeEdit(_ space: Space, draft: String) {
        editingSpace = space
        model.title = MemoEditTarget.editingTitle(names.displayName(for: space))
        model.draft = draft
        model.isEditing = true
        panel.alphaValue = 1
        focus.take(for: panel)
    }

    private func save(_ text: String) {
        switch MemoEditTarget.resolve(editing: editingSpace, in: SpaceProvider.spaces()) {
        case .save(let space):
            memos.setMemo(text, for: space.id, desktopName: names.displayName(for: space))
        case .gone:
            keepUnsavedText(text)
        case .nothing:
            break
        }
        endEdit()
    }

    /// The edited desktop vanished mid-edit: don't write it anywhere else, hand the text back instead.
    private func keepUnsavedText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        let alert = NSAlert()
        alert.messageText = "편집하던 데스크탑이 없어져 메모를 저장하지 못했어요"
        alert.informativeText = "작성한 내용은 클립보드에 복사해 두었어요."
        alert.runModal()
    }

    /// Checkbox click (#19): flip that line in the file without entering edit mode.
    private func toggleTask(_ line: Int) {
        guard let space = currentSpace, let memo = memos.memo(for: space.id) else { return }
        memos.setMemo(MarkdownBlocks.toggleTask(in: memo, line: line), for: space.id, desktopName: names.displayName(for: space))
    }

    private func endEdit() {
        editingSpace = nil
        model.isEditing = false
        focus.giveBack()
        refresh()
    }

    // MARK: window

    private func settingsChanged() {
        let oldLayout = settings.layout(for: currentSpace?.id)
        let oldCorner = settings.corner
        settings = MemoSettings.load()
        if !applyingFrame, oldCorner != settings.corner || oldLayout != settings.layout(for: currentSpace?.id) {
            placePanel()
        }
        updateVisibility()
    }

    /// Applies the current desktop's layout (#24), falling back to the shared one, then the corner default.
    private func placePanel() {
        guard let screen = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame else { return }
        let layout = settings.layout(for: currentSpace?.id)
        var frame = layout.frame.map { MemoSettings.clamp($0, to: screen) }
            ?? CGRect(origin: settings.corner.origin(for: MemoSettings.defaultSize, in: screen), size: MemoSettings.defaultSize)
        model.isCollapsed = layout.collapsed
        if layout.collapsed {
            // Keep the top edge where it was and shrink to the title bar.
            frame.origin.y = frame.maxY - MemoOverlayPanel.collapsedHeight
            frame.size.height = MemoOverlayPanel.collapsedHeight
        }
        applyingFrame = true
        panel.setFrame(frame, display: true)
        applyingFrame = false
        placedFor = .some(currentSpace?.id)
    }

    /// Collapse/expand this desktop's memo only (#24).
    private func toggleCollapse() {
        var s = MemoSettings.load()
        var layout = s.layout(for: currentSpace?.id)
        if !layout.collapsed { layout.frame = panel.frame }  // expanding later restores this frame
        layout.collapsed.toggle()
        s.setLayout(layout, for: currentSpace?.id)
        s.save()
    }

    private func applyOpacity(hovering: Bool) {
        panel.alphaValue = (hovering || model.isEditing) ? 1 : settings.opacity
    }

    /// A drag or resize belongs to the desktop on screen (#24).
    private func rememberFrame() {
        guard !applyingFrame else { return }
        var s = MemoSettings.load()
        var layout = s.layout(for: currentSpace?.id)
        guard !layout.collapsed else { return }
        layout.frame = panel.frame
        s.setLayout(layout, for: currentSpace?.id)
        settings = s
        applyingFrame = true
        s.save()
        applyingFrame = false
    }

    func windowDidMove(_ notification: Notification) { rememberFrame() }
    func windowDidEndLiveResize(_ notification: Notification) { rememberFrame() }
}

final class MemoOverlayModel: ObservableObject {
    @Published var title = ""
    @Published var memo: String?
    @Published var canEdit = true
    @Published var isEditing = false
    @Published var isCollapsed = false
    /// First visible block of the memo; mouse scrolling updates it, desktop changes restore it (#25).
    @Published var scrollLine = 0
    /// Whose memo is shown; a new value gives a fresh scroll view opened at `scrollLine`.
    @Published var scrollKey = ""
    @Published var draft = ""

    var onEdit: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onToggleCollapse: () -> Void = {}
    var onHover: (Bool) -> Void = { _ in }
    var onToggleTask: (Int) -> Void = { _ in }
}

/// Titled-but-chromeless panel: free to drag (by its background) and resize, never activates the app
/// by itself, sits above normal and floating windows on every Space, fullscreen apps included.
final class MemoOverlayPanel: NSPanel {
    static let collapsedHeight: CGFloat = 34

    init(model: MemoOverlayModel, delegate: NSWindowDelegate) {
        super.init(contentRect: CGRect(origin: .zero, size: MemoSettings.defaultSize),
                   styleMask: [.titled, .resizable, .nonactivatingPanel, .fullSizeContentView],
                   backing: .buffered, defer: true)
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        isMovableByWindowBackground = true
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        minSize = CGSize(width: 200, height: Self.collapsedHeight)
        self.delegate = delegate

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true
        let hosting = NSHostingView(rootView: MemoOverlayView(model: model))
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

    override var canBecomeKey: Bool { true }
}

struct MemoOverlayView: View {
    @ObservedObject var model: MemoOverlayModel
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            if !model.isCollapsed {
                if model.isEditing {
                    editor
                } else {
                    content
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, model.isCollapsed ? 8 : 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onHover { model.onHover($0) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(model.title)
                .font(.headline)
                .lineLimit(1)
            Spacer()
            if model.canEdit && !model.isEditing {
                Button(action: model.onEdit) { Image(systemName: "pencil") }
                    .buttonStyle(.borderless)
                    .help("메모 편집 (더블클릭도 가능)")
            }
            Button(action: model.onToggleCollapse) {
                Image(systemName: model.isCollapsed ? "chevron.down" : "chevron.up")
            }
            .buttonStyle(.borderless)
            .help(model.isCollapsed ? "펼치기" : "접기")
        }
        .frame(height: 18)
    }

    private var content: some View {
        ScrollViewReader { proxy in
        ScrollView {
            Group {
                if let memo = model.memo {
                    MarkdownView(text: memo, onToggleTask: model.onToggleTask)
                        .textSelection(.enabled)
                } else {
                    Text(model.canEdit ? "메모 없음 · 클릭해 추가" : "전체화면 앱에는 메모를 둘 수 없어요")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollPosition(id: Binding(get: { model.scrollLine },
                                    set: { if let line = $0 { model.scrollLine = line } }),
                        anchor: .top)
        .onAppear {
            let line = model.scrollLine
            DispatchQueue.main.async { proxy.scrollTo(line, anchor: .top) }
        }
        }
        .id(model.scrollKey)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.onEdit() }
        .onTapGesture { if model.memo == nil { model.onEdit() } }
    }

    private var editor: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $model.draft)
                .font(.system(.callout, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                .focused($editorFocused)
                .onAppear { editorFocused = true }
                .onKeyPress(.return, phases: .down) { press in
                    guard press.modifiers.contains(.command) else { return .ignored }
                    model.onSave(model.draft)
                    return .handled
                }
                .onKeyPress(.escape) {
                    model.onCancel()
                    return .handled
                }
            HStack {
                Text("⌘Enter 저장 · Esc 취소").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button("취소", action: model.onCancel)
                Button("저장") { model.onSave(model.draft) }   // no Enter shortcut: Enter is a newline here
            }
        }
    }
}
