import SwiftUI

/// Renders a memo with the `MarkdownBlocks` subset (#19). Inline bold/italic/code/links go through
/// `AttributedString(markdown:)`; links open in the browser. Task boxes are clickable when
/// `onToggleTask` is set; it receives the source line to flip (`MarkdownBlocks.toggleTask`).
struct MarkdownView: View {
    let text: String
    var onToggleTask: ((Int) -> Void)?

    private static let indent: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(MarkdownBlocks.parse(text).enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(index)
            }
        }
        .scrollTargetLayout()   // blocks are what a surrounding ScrollView reports as its position (#25)
        .font(.callout)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case let .heading(level, text):
            inline(text)
                .font(level == 1 ? .title3.weight(.bold) : level == 2 ? .headline : .subheadline.weight(.semibold))
                .padding(.top, 2)
        case let .bullet(level, text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(level == 0 ? "•" : "◦").foregroundColor(.secondary)
                inline(text)
            }
            .padding(.leading, CGFloat(level) * Self.indent)
        case let .numbered(number, text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").monospacedDigit().foregroundColor(.secondary)
                inline(text)
            }
        case let .task(checked, level, text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Button { onToggleTask?(block.line) } label: {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .foregroundColor(checked ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(onToggleTask == nil)
                .help(onToggleTask == nil ? "" : (checked ? "완료 취소" : "완료"))
                inline(text)
                    .strikethrough(checked)
                    .foregroundColor(checked ? .secondary : .primary)
            }
            .padding(.leading, CGFloat(level) * Self.indent)
        case let .code(lines):
            Text(lines.joined(separator: "\n"))
                .font(.system(.callout, design: .monospaced))
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
        case let .quote(text):
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.5)).frame(width: 3)
                inline(text).foregroundColor(.secondary)
            }
        case .rule:
            Divider().padding(.vertical, 2)
        case .blank:
            Color.clear.frame(height: 4)
        case let .paragraph(text):
            inline(text)
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        guard let attributed = try? AttributedString(markdown: text, options: options) else { return Text(text) }
        return Text(attributed)
    }
}
