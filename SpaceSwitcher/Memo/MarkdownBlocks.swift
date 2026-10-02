import Foundation

/// One rendered unit of a memo (#19). `line` is the source line it came from (0-based).
struct MarkdownBlock: Equatable {
    enum Kind: Equatable {
        case heading(level: Int, text: String)
        case bullet(level: Int, text: String)
        case numbered(number: Int, text: String)
        case task(checked: Bool, level: Int, text: String)
        case code([String])
        case quote(String)
        case rule
        case blank
        case paragraph(String)
    }

    let kind: Kind
    let line: Int
}

/// Line-based parser for the Markdown subset memos support: headings, bullet/numbered lists,
/// task checkboxes, fenced code, quotes, rules. Inline styling (bold, code, links) is left in the
/// text for `AttributedString(markdown:)`. Pure; no external dependencies (CLAUDE.md).
enum MarkdownBlocks {
    static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                let start = index
                var code: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                blocks.append(MarkdownBlock(kind: .code(code), line: start))
                index += 1  // skip the closing fence (or step past the end)
                continue
            }
            blocks.append(MarkdownBlock(kind: kind(of: line, trimmed: trimmed), line: index))
            index += 1
        }
        return blocks
    }

    /// Flips `[ ]` ↔ `[x]` on `line` if it is a task item; any other text is returned unchanged.
    static func toggleTask(in text: String, line: Int) -> String {
        var lines = text.components(separatedBy: "\n")
        guard lines.indices.contains(line), let match = taskMatch(lines[line]) else { return text }
        let box = lines[line].index(lines[line].startIndex, offsetBy: match.boxOffset)
        let after = lines[line].index(box, offsetBy: 3)
        lines[line].replaceSubrange(box..<after, with: match.checked ? "[ ]" : "[x]")
        return lines.joined(separator: "\n")
    }

    // MARK: -

    private static func kind(of line: String, trimmed: String) -> MarkdownBlock.Kind {
        if trimmed.isEmpty { return .blank }
        if trimmed == "---" || trimmed == "***" || trimmed == "___" { return .rule }

        if trimmed.hasPrefix("#") {
            let hashes = trimmed.prefix(while: { $0 == "#" }).count
            let rest = trimmed.dropFirst(hashes)
            if (1...6).contains(hashes), rest.first == " " {
                return .heading(level: min(hashes, 3), text: rest.trimmingCharacters(in: .whitespaces))
            }
        }
        if trimmed.hasPrefix("> ") || trimmed == ">" {
            return .quote(String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces))
        }

        let level = indentLevel(line)
        if let task = taskMatch(line) {
            return .task(checked: task.checked, level: level, text: task.text)
        }
        if let first = trimmed.first, first == "-" || first == "*" || first == "+", trimmed.dropFirst().first == " " {
            return .bullet(level: level, text: trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces))
        }
        let digits = trimmed.prefix(while: \.isNumber)
        if !digits.isEmpty, let number = Int(digits) {
            let rest = trimmed.dropFirst(digits.count)
            if let marker = rest.first, marker == "." || marker == ")", rest.dropFirst().first == " " {
                return .numbered(number: number, text: rest.dropFirst(2).trimmingCharacters(in: .whitespaces))
            }
        }
        return .paragraph(trimmed)
    }

    /// Two spaces (or a tab) per nesting level.
    private static func indentLevel(_ line: String) -> Int {
        var width = 0
        for c in line {
            if c == " " { width += 1 } else if c == "\t" { width += 2 } else { break }
        }
        return width / 2
    }

    /// `- [ ] text`, `* [x] text`, `+ [X] text` (any indent). `boxOffset` is where `[` sits in `line`.
    private static func taskMatch(_ line: String) -> (checked: Bool, text: String, boxOffset: Int)? {
        let indent = line.prefix(while: { $0 == " " || $0 == "\t" }).count
        let body = Array(line.dropFirst(indent))
        guard body.count >= 5, "-*+".contains(body[0]), body[1] == " ", body[2] == "[", body[4] == "]",
              body.count == 5 || body[5] == " " else { return nil }
        let mark = body[3]
        guard mark == " " || mark == "x" || mark == "X" else { return nil }
        let text = String(body.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        return (mark != " ", text, indent + 2)
    }
}
