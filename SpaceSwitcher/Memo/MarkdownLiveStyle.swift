import Foundation

/// One styled stretch of a memo's source (#27). Ranges are UTF-16 (`NSString`) offsets.
struct LiveStyleRun: Equatable {
    enum Kind: Equatable {
        /// Markdown markers: hidden away from the caret line, dimmed on it.
        case syntax
        /// Heading text, level 1…3 (4–6 look like 3).
        case heading(Int)
        case bold, italic, code, strike
        case link(String)
        /// The `-`/`*`/`+` of a bullet: drawn as • away from the caret line.
        case bullet
        /// The `[ ]`/`[x]` of a task: drawn as a checkbox away from the caret line.
        case task(checked: Bool)
        /// Text of a checked task.
        case done
        case quote
        /// ``` lines, and the lines between them.
        case fence, codeBlock
        /// `---`: drawn as a line away from the caret line.
        case rule
    }

    let range: NSRange
    let line: Int
    let kind: Kind
}

/// Live-preview styling for the memo editor (#27): the text stays the Markdown source, and these runs
/// say which characters to hide, restyle or draw over. Covers the `MarkdownBlocks` subset plus inline
/// bold/italic/code/strike/links. Pure.
enum MarkdownLiveStyle {
    static func runs(in text: String) -> [LiveStyleRun] {
        let s = text as NSString
        var runs: [LiveStyleRun] = []
        var inFence = false
        var line = 0
        var start = 0
        while start <= s.length {
            let end = lineEnd(s, from: start)
            let lineRange = NSRange(location: start, length: end - start)
            let trimmed = s.substring(with: lineRange).trimmingCharacters(in: .whitespaces)
            func add(_ location: Int, _ length: Int, _ kind: LiveStyleRun.Kind) {
                if length > 0 { runs.append(LiveStyleRun(range: NSRange(location: location, length: length), line: line, kind: kind)) }
            }

            if trimmed.hasPrefix("```") {
                add(start, end - start, .fence)
                inFence.toggle()
            } else if inFence {
                add(start, end - start, .codeBlock)
            } else {
                block(s, start, end, add: add)
            }

            guard end < s.length else { break }
            start = end + 1   // past "\n"
            line += 1
        }
        return runs
    }

    /// Lines the selection touches; the caret line(s) show their raw source.
    static func lines(touching selection: NSRange, in text: String) -> ClosedRange<Int> {
        let first = line(at: selection.location, in: text)
        let last = line(at: NSMaxRange(selection), in: text)
        return first...max(first, last)
    }

    static func line(at offset: Int, in text: String) -> Int {
        let s = text as NSString
        let upTo = min(max(0, offset), s.length)
        var count = 0
        for i in 0..<upTo where s.character(at: i) == newline { count += 1 }
        return count
    }

    static func lineCount(_ text: String) -> Int {
        line(at: (text as NSString).length, in: text) + 1
    }

    /// UTF-16 offset where `line` begins (the end of the text past the last line).
    static func lineStart(_ line: Int, in text: String) -> Int {
        let s = text as NSString
        var start = 0
        for _ in 0..<max(0, line) {
            let end = lineEnd(s, from: start)
            guard end < s.length else { return s.length }
            start = end + 1
        }
        return start
    }

    // MARK: - blocks

    private static let newline = unichar(10)

    private static func lineEnd(_ s: NSString, from start: Int) -> Int {
        var i = start
        while i < s.length, s.character(at: i) != newline { i += 1 }
        return i
    }

    private static func block(_ s: NSString, _ start: Int, _ end: Int, add: (Int, Int, LiveStyleRun.Kind) -> Void) {
        var i = start
        while i < end, isSpace(s.character(at: i)) { i += 1 }
        let rest = s.substring(with: NSRange(location: i, length: end - i))
        let trimmed = rest.trimmingCharacters(in: .whitespaces)

        // Rule
        if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            add(i, end - i, .rule)
            return
        }
        // Heading
        if char(s, i) == "#" {
            var j = i
            while j < end, char(s, j) == "#" { j += 1 }
            let level = j - i
            if (1...6).contains(level), j < end, char(s, j) == " " {
                var k = j
                while k < end, char(s, k) == " " { k += 1 }
                add(start, k - start, .syntax)
                add(k, end - k, .heading(min(level, 3)))
                inline(s, k, end, add: add)
                return
            }
        }
        // Quote
        if char(s, i) == ">" {
            var k = i + 1
            if k < end, char(s, k) == " " { k += 1 }
            add(start, k - start, .syntax)
            add(k, end - k, .quote)
            inline(s, k, end, add: add)
            return
        }
        // Task / bullet
        if let marker = char(s, i), "-*+".contains(marker), char(s, i + 1) == " " {
            if char(s, i + 2) == "[", let mark = char(s, i + 3), " xX".contains(mark), char(s, i + 4) == "]",
               i + 5 == end || char(s, i + 5) == " " {
                add(i, 2, .syntax)
                add(i + 2, 3, .task(checked: mark != " "))
                var k = i + 5
                while k < end, char(s, k) == " " { k += 1 }
                if mark != " " { add(k, end - k, .done) }
                inline(s, k, end, add: add)
                return
            }
            add(i, 1, .bullet)
            inline(s, i + 2, end, add: add)
            return
        }
        inline(s, start, end, add: add)
    }

    // MARK: - inline

    private static func inline(_ s: NSString, _ start: Int, _ end: Int, add: (Int, Int, LiveStyleRun.Kind) -> Void) {
        var i = start
        while i < end {
            let c = char(s, i)
            if c == "`", let j = find("`", in: s, from: i + 1, to: end), j > i + 1 {
                wrap(i, 1, j, 1, .code, add); i = j + 1; continue
            }
            if c == "*", char(s, i + 1) == "*", let j = find("**", in: s, from: i + 2, to: end), j > i + 2 {
                wrap(i, 2, j, 2, .bold, add); i = j + 2; continue
            }
            if c == "~", char(s, i + 1) == "~", let j = find("~~", in: s, from: i + 2, to: end), j > i + 2 {
                wrap(i, 2, j, 2, .strike, add); i = j + 2; continue
            }
            if c == "*", char(s, i + 1) != "*", char(s, i + 1) != " ",
               let j = find("*", in: s, from: i + 1, to: end), j > i + 1, char(s, j - 1) != " " {
                wrap(i, 1, j, 1, .italic, add); i = j + 1; continue
            }
            if c == "_", i == start || !isWordChar(s.character(at: i - 1)),
               let j = closingUnderscore(s, from: i + 1, to: end), j > i + 1 {
                wrap(i, 1, j, 1, .italic, add); i = j + 1; continue
            }
            if c == "[", let k = find("](", in: s, from: i + 1, to: end), k > i + 1,
               let m = find(")", in: s, from: k + 2, to: end) {
                let url = s.substring(with: NSRange(location: k + 2, length: m - k - 2))
                add(i, 1, .syntax)
                add(i + 1, k - i - 1, .link(url))
                add(k, m - k + 1, .syntax)
                i = m + 1; continue
            }
            i += 1
        }
    }

    private static func wrap(_ open: Int, _ openLength: Int, _ close: Int, _ closeLength: Int, _ kind: LiveStyleRun.Kind,
                             _ add: (Int, Int, LiveStyleRun.Kind) -> Void) {
        add(open, openLength, .syntax)
        add(open + openLength, close - open - openLength, kind)
        add(close, closeLength, .syntax)
    }

    private static func closingUnderscore(_ s: NSString, from: Int, to end: Int) -> Int? {
        var j = from
        while let found = find("_", in: s, from: j, to: end) {
            if found + 1 >= end || !isWordChar(s.character(at: found + 1)) { return found }
            j = found + 1
        }
        return nil
    }

    private static func find(_ needle: String, in s: NSString, from: Int, to end: Int) -> Int? {
        guard from < end else { return nil }
        let r = s.range(of: needle, options: .literal, range: NSRange(location: from, length: end - from))
        return r.location == NSNotFound ? nil : r.location
    }

    private static func char(_ s: NSString, _ i: Int) -> Character? {
        guard i >= 0, i < s.length, let scalar = Unicode.Scalar(s.character(at: i)) else { return nil }
        return Character(scalar)
    }

    private static func isSpace(_ c: unichar) -> Bool { c == 32 || c == 9 }

    private static func isWordChar(_ c: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(c) else { return true }   // surrogate half: part of a word
        return CharacterSet.alphanumerics.contains(scalar)
    }
}
