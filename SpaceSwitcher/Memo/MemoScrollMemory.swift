import Foundation

/// Where each desktop's memo was being read (#25), as the first visible block rather than pixels so it
/// still lands near the same text after a resize. Persisted under its own UserDefaults key, so it
/// survives app restarts; `init()` keeps it in memory only.
struct MemoScrollMemory {
    private var lines: [String: Int] = [:]
    private let key: String?
    private let defaults: UserDefaults

    init() {
        key = nil
        defaults = .standard
    }

    init(persistingAs key: String, in defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
        lines = defaults.dictionary(forKey: key) as? [String: Int] ?? [:]
    }

    mutating func set(_ line: Int, for spaceID: String?) {
        guard let spaceID, lines[spaceID] != line else { return }
        lines[spaceID] = line
        save()
    }

    /// The remembered block, pulled back to the last one when the memo got shorter.
    func position(for spaceID: String?, blockCount: Int) -> Int {
        let line = spaceID.flatMap { lines[$0] } ?? 0
        return min(max(0, line), max(0, blockCount - 1))
    }

    /// Forgets desktops that no longer exist.
    mutating func prune(keeping ids: Set<String>) {
        let kept = lines.filter { ids.contains($0.key) }
        guard kept.count != lines.count else { return }
        lines = kept
        save()
    }

    private func save() {
        if let key { defaults.set(lines, forKey: key) }
    }
}
