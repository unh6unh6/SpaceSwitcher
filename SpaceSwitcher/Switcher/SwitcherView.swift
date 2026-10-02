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
        /// Multi-line note for this desktop (#17).
        var description: String? = nil
    }

    @Published var rows: [Row] = []
    @Published var selection = 0
    @Published var renamingRow: Int?
    @Published var draft = ""
    /// The description area appears once any desktop has a description (#17).
    @Published var showsDescriptionArea = false
    @Published var describingRow: Int?
    @Published var descriptionDraft = ""

    var selectedDescription: String? {
        rows.indices.contains(selection) ? rows[selection].description : nil
    }

    var onClick: (Int) -> Void = { _ in }
    var onDoubleClick: (Int) -> Void = { _ in }
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
    var onCommitDescription: (String) -> Void = { _ in }
    var onCancelDescription: () -> Void = {}
}

struct SwitcherView: View {
    /// Tall enough for 16 rows without scrolling on a 13" screen (SPEC §3.2).
    static let rowHeight: CGFloat = 30

    @ObservedObject var model: SwitcherViewModel
    @FocusState private var fieldFocused: Bool
    @FocusState private var editorFocused: Bool
    /// Fixed height (~4 lines) so moving the selection never resizes the panel (#17).
    static let descriptionHeight: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { i, row in
                rowView(row, index: i)
            }
            if model.showsDescriptionArea || model.describingRow != nil {
                descriptionArea
            }
            Text(model.describingRow != nil
                 ? "⌘Enter 저장 · Enter 줄바꿈 · Esc 취소"
                 : "↑↓ 이동 · Enter 전환 · 1–9 바로 이동 · R 이름 · D 설명 · Esc 닫기")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, 10)
        }
        .padding(10)
        .frame(width: model.rows.contains { $0.apps != nil } ? 440 : 340)
    }

    /// The selected desktop's description, or its editor while describing.
    private var descriptionArea: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().padding(.vertical, 6)
            Group {
                if model.describingRow != nil {
                    TextEditor(text: $model.descriptionDraft)
                        .font(.callout)
                        .scrollContentBackground(.hidden)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                        .focused($editorFocused)
                        .onAppear { editorFocused = true }
                        .onKeyPress(.return, phases: .down) { press in
                            guard press.modifiers.contains(.command) else { return .ignored }  // plain Enter = newline
                            model.onCommitDescription(model.descriptionDraft)
                            return .handled
                        }
                        .onKeyPress(.escape) {
                            model.onCancelDescription()
                            return .handled
                        }
                } else if let text = model.selectedDescription {
                    Text(text)
                        .font(.callout)
                        .lineLimit(4)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    Text("설명 없음 · D로 추가")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(height: Self.descriptionHeight)
            .padding(.horizontal, 10)
        }
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
