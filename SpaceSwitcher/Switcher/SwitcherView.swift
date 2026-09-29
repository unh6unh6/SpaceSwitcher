import SwiftUI

final class SwitcherViewModel: ObservableObject {
    struct Row: Identifiable, Equatable {
        let id: String
        let number: Int
        let title: String
        let isNamed: Bool
        let isCurrent: Bool
    }

    @Published var rows: [Row] = []
    @Published var selection = 0
    @Published var renamingRow: Int?
    @Published var draft = ""

    var onClick: (Int) -> Void = { _ in }
    var onDoubleClick: (Int) -> Void = { _ in }
    var onCommitRename: (String) -> Void = { _ in }
    var onCancelRename: () -> Void = {}
}

struct SwitcherView: View {
    /// Tall enough for 16 rows without scrolling on a 13" screen (SPEC §3.2).
    static let rowHeight: CGFloat = 30

    @ObservedObject var model: SwitcherViewModel
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(model.rows.enumerated()), id: \.element.id) { i, row in
                rowView(row, index: i)
            }
            Text("↑↓ 이동 · Enter 전환 · 1–9 바로 이동 · R 이름 변경 · Esc 닫기")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
                .padding(.horizontal, 10)
        }
        .padding(10)
        .frame(width: 340)
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
