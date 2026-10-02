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
    /// Frame changes we make ourselves must not be saved back as "the user moved it".
    private var applyingFrame = false

    init(names: NameStore, memos: MemoStore) {
        self.names = names
        self.memos = memos
        super.init()
        model.onEdit = { [weak self] in self?.beginEdit() }
        model.onSave = { [weak self] text in self?.save(text) }
        model.onCancel = { [weak self] in self?.endEdit() }
        model.onToggleCollapse = { [weak self] in self?.toggleCollapse() }
        model.onHover = { [weak self] inside in self?.applyOpacity(hovering: inside) }

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
        currentSpace = SpaceProvider.spaces().first(where: \.isCurrent)
        guard model.isEditing == false else { return }  // never yank text out from under the editor
        model.title = currentSpace.map(names.displayName) ?? "전체화면"
        model.memo = currentSpace.flatMap { memos.memo(for: $0.id) }
        model.canEdit = currentSpace != nil
        updateVisibility()
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
        guard currentSpace != nil else { return }
        if settings.collapsed { toggleCollapse() }
        model.draft = model.memo ?? ""
        model.isEditing = true
        panel.alphaValue = 1
        focus.take(for: panel)
    }

    private func save(_ text: String) {
        if let space = currentSpace {
            memos.setMemo(text, for: space.id, desktopName: names.displayName(for: space))
        }
        endEdit()
    }

    private func endEdit() {
        model.isEditing = false
        focus.giveBack()
        refresh()
    }

    // MARK: window

    private func settingsChanged() {
        let old = settings
        settings = MemoSettings.load()
        let moved = old.corner != settings.corner || (old.frame != settings.frame && !applyingFrame)
        if moved || old.collapsed != settings.collapsed { placePanel() }
        updateVisibility()
    }

    private func placePanel() {
        guard let screen = (NSScreen.screens.first ?? NSScreen.main)?.visibleFrame else { return }
        var frame = settings.frame.map { MemoSettings.clamp($0, to: screen) }
            ?? CGRect(origin: settings.corner.origin(for: MemoSettings.defaultSize, in: screen), size: MemoSettings.defaultSize)
        model.isCollapsed = settings.collapsed
        if settings.collapsed {
            // Keep the top edge where it was and shrink to the title bar.
            frame.origin.y = frame.maxY - MemoOverlayPanel.collapsedHeight
            frame.size.height = MemoOverlayPanel.collapsedHeight
        }
        applyingFrame = true
        panel.setFrame(frame, display: true)
        applyingFrame = false
    }

    private func toggleCollapse() {
        // Remember the expanded frame before collapsing so expanding restores it.
        if !settings.collapsed { rememberFrame() }
        var s = MemoSettings.load()
        s.collapsed.toggle()
        s.save()
    }

    private func applyOpacity(hovering: Bool) {
        panel.alphaValue = (hovering || model.isEditing) ? 1 : settings.opacity
    }

    private func rememberFrame() {
        guard !applyingFrame, !settings.collapsed else { return }
        var s = MemoSettings.load()
        s.frame = panel.frame
        settings.frame = panel.frame
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
    @Published var draft = ""

    var onEdit: () -> Void = {}
    var onSave: (String) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onToggleCollapse: () -> Void = {}
    var onHover: (Bool) -> Void = { _ in }
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
        ScrollView {
            Group {
                if let memo = model.memo {
                    Text(memo)
                        .font(.callout)
                        .textSelection(.enabled)
                } else {
                    Text(model.canEdit ? "메모 없음 · 클릭해 추가" : "전체화면 앱에는 메모를 둘 수 없어요")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
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
