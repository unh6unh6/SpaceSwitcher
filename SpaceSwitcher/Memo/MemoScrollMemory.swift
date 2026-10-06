import Foundation

/// Where each desktop's memo was being read (#25), as the first visible block rather than pixels so it
/// still lands near the same text after a resize. In memory only: an app restart starts at the top. Pure.
struct MemoScrollMemory {
    private var lines: [String: Int] = [:]

    mutating func set(_ line: Int, for spaceID: String?) {
        guard let spaceID else { return }
        lines[spaceID] = line
    }

    /// The remembered block, pulled back to the last one when the memo got shorter.
    func position(for spaceID: String?, blockCount: Int) -> Int {
        let line = spaceID.flatMap { lines[$0] } ?? 0
        return min(max(0, line), max(0, blockCount - 1))
    }
}
