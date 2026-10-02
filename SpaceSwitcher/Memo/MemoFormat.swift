import Foundation

/// On-disk format of a desktop memo (#18): a Markdown file whose front matter names the desktop.
///
///     ---
///     space: 276CC097-9F18-4FDA-BDCB-EDC5B1744BD0
///     ---
///     ## 오늘
///     - [ ] 환불 API 테스트
///
/// The `space` key (the desktop uuid) links file and desktop, so the file can be renamed or edited
/// in any editor. Other front matter keys are preserved. Pure.
enum MemoFormat {
    static let spaceKey = "space"
    static let fileExtension = "md"

    struct Parsed: Equatable {
        var spaceID: String?
        var body: String
        /// Front matter lines other than `space:`, kept verbatim.
        var otherFrontMatter: [String]
    }

    static func parse(_ text: String) -> Parsed {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        guard lines.first == "---", let close = lines.dropFirst().firstIndex(of: "---") else {
            return Parsed(spaceID: nil, body: trimmed(normalized), otherFrontMatter: [])
        }
        var spaceID: String?
        var others: [String] = []
        for line in lines[1..<close] {
            if let value = value(of: spaceKey, in: line) {
                spaceID = value
            } else {
                others.append(line)
            }
        }
        let body = lines[(close + 1)...].joined(separator: "\n")
        return Parsed(spaceID: spaceID, body: trimmed(body), otherFrontMatter: others)
    }

    static func serialize(spaceID: String, body: String, keeping others: [String]) -> String {
        (["---"] + others + ["\(spaceKey): \(spaceID)", "---", trimmed(body)]).joined(separator: "\n") + "\n"
    }

    /// `"업무.md"`, or `"업무 2.md"` … when taken (case-insensitive, as on APFS by default).
    static func fileName(for desktopName: String, taken: Set<String>) -> String {
        var base = desktopName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasPrefix(".") { base.removeFirst() }  // no hidden files
        if base.isEmpty { base = "데스크탑" }
        base = String(base.prefix(80))

        let lowercasedTaken = Set(taken.map { $0.lowercased() })
        var candidate = "\(base).\(fileExtension)"
        var number = 2
        while lowercasedTaken.contains(candidate.lowercased()) {
            candidate = "\(base) \(number).\(fileExtension)"
            number += 1
        }
        return candidate
    }

    private static func value(of key: String, in line: String) -> String? {
        let parts = line.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, parts[0].trimmingCharacters(in: .whitespaces) == key else { return nil }
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
