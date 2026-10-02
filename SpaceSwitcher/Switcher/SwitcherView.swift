import AppKit
import SwiftUI

final class SwitcherViewModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: String
        let number: Int
        let title: String
        let isNamed: Bool
        let isCurrent: Bool
        /// Apps with windows on this desktop (#14); nil when the setting is off.
        var apps: [SpaceApps.App]? = nil
        var overflow = 0
        /// This desktop's memo file (#18).
        var memo: String? = nil
    }

    @Published var rows: [Row] = []
    @Published var selection = 0 {
        didSet { if selection != oldValue { memoScrollLine = 0 } }
    }
    @Published var renamingRow: Int?
    @Published var draft = ""
    /// Memo preview beside the list (#20): on in Settings and at least one desktop has a memo.
    @Published var showsMemoPreview = false
    @Published var editingMemoRow: Int?
    @Published var memoDraft = ""
    /// First visible line of the preview; Shift+↑↓ moves it.
    @Published var memoScrollLine = 0

    var selectedRow: Row? { rows.indices.contains(selection) ? rows[selection] : nil }

    /// Lines per Shift+↑↓ press.
    static let scrollStep = 4

    func scrollMemo(by steps: Int) {
        let lineCount = selectedRow?.memo?.components(separatedBy: "\n").count ?? 0
        memoScrollLine = min(max(0, memoScrollLine + steps * Self.scrollStep), max(0, lineCount - 1))
    }

    var onClick: (Int) -> Void = { _ in }
    var onDoubleClick: (Int) -> Void = { _ in }
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
    var onCommitMemo: (String) -> Void = { _ in }
    var onCancelMemo: () -> Void = {}
}

struct SwitcherView: View {
    /// Tall enough for 16 rows without scrolling on a 13" screen (SPEC §3.2).
    static let rowHeight: CGFloat = 30
    static let previewWidth: CGFloat = 380
    /// The preview never gets shorter than this, even next to a 2-desktop list.
    static let previewMinHeight: CGFloat = 240

    @ObservedObject var model: SwitcherViewModel
    @FocusState private var fieldFocused: Bool
    @FocusState private var editorFocused: Bool

    private var showsPreview: Bool { model.showsMemoPreview || model.editingMemoRow != nil }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            list
                .frame(width: model.rows.contains { $0.apps != nil } ? 440 : 340)
            if showsPreview {
                Divider()
                memoPreview
                    .frame(width: Self.previewWidth, height: previewHeight, alignment: .top)
            }
        }
        .padding(10)
    }

    /// As tall as the list (min 240) and never taller: a long memo scrolls instead of stretching
    /// the panel, and moving the selection never resizes it.
    private var previewHeight: CGFloat {
        let listHeight = CGFloat(model.rows.count) * (Self.rowHeight + 2) + 28
        return max(listHeight, Self.previewMinHeight)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { i, row in
                rowView(row, index: i)
            }
            if showsPreview { Spacer(minLength: 0) }
            Text(model.editingMemoRow != nil
                 ? "⌘Enter 저장 · Enter 줄바꿈 · Esc 취소"
                 : "↑↓ 이동 · Enter 전환 · 1–9 바로 · R 이름 · D 메모" + (showsPreview ? " · ⇧↑↓ 스크롤" : "") + " · Esc")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, 10)
        }
    }

    /// The selected desktop's memo, scrollable; or its editor while editing (#20).
    private var memoPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.selectedRow?.title ?? "")
                .font(.headline)
                .lineLimit(1)
            if model.editingMemoRow != nil {
                TextEditor(text: $model.memoDraft)
                    .font(.system(.callout, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                    .focused($editorFocused)
                    .onAppear { editorFocused = true }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.command) else { return .ignored }  // plain Enter = newline
                        model.onCommitMemo(model.memoDraft)
                        return .handled
                    }
                    .onKeyPress(.escape) {
                        model.onCancelMemo()
                        return .handled
                    }
            } else if let memo = model.selectedRow?.memo {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(memo.components(separatedBy: "\n").enumerated()), id: \.offset) { i, line in
                                Text(line.isEmpty ? " " : line)
                                    .font(.callout)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(i)
                            }
                        }
                    }
                    .onChange(of: model.memoScrollLine) { _, line in
                        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(line, anchor: .top) }
                    }
                }
            } else {
                Text("메모 없음 · D로 작성")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// Up to 5 app icons, "+N" for the rest, or "(비어 있음)" for a desktop without windows.
    @ViewBuilder
    private func appIcons(_ apps: [SpaceApps.App], overflow: Int, selected: Bool) -> some View {
        if apps.isEmpty {
            Text("(비어 있음)")
                .font(.caption)
                .foregroundStyle(selected ? .white.opacity(0.7) : .secondary)
        } else {
            HStack(spacing: 3) {
                ForEach(apps, id: \.pid) { app in
                    if let icon = NSRunningApplication(processIdentifier: app.pid)?.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .help(app.name)
                    }
                }
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(.caption)
                        .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: SwitcherViewModel.Row, index: Int) -> some View {
        let selected = index == model.selection
        HStack(spacing: 10) {
            Text("\(row.number)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(selected ? .white.opacity(0.8) : .secondary)
                .frame(width: 22, alignment: .trailing)

            if model.renamingRow == index {
                TextField(row.isNamed ? "" : row.title, text: $model.draft)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit { model.onCommitRename(model.draft) }
                    .onExitCommand { model.onCancelRename() }
                    .onAppear { fieldFocused = true }
            } else {
                Text(row.title)
                    .foregroundStyle(selected ? .white : (row.isNamed ? .primary : .secondary))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)
            if let apps = row.apps, model.renamingRow != index {
                appIcons(apps, overflow: row.overflow, selected: selected)
            }
            if row.isCurrent {
                Text("현재")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(selected ? Color.white.opacity(0.25) : Color.secondary.opacity(0.2)))
                    .foregroundStyle(selected ? .white : .secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: Self.rowHeight)
        .background(RoundedRectangle(cornerRadius: 6).fill(selected ? Color.accentColor : .clear))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { model.onDoubleClick(index) }
        .onTapGesture { model.onClick(index) }
    }
}
