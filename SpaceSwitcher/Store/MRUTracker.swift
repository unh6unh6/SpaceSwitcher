import Foundation

/// Most-recently-used desktops, newest first. Only decides the switcher's initial selection;
/// the list itself is always shown in desktop order (SPEC §3.3). Kept in memory only.
struct MRUTracker {
    private(set) var order: [String] = []

    mutating func visit(_ id: String) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
    }

    /// The most recent desktop other than `current` that still exists.
    func previous(current: String?, existing: Set<String>) -> String? {
        order.first { $0 != current && existing.contains($0) }
    }

    /// Row to preselect: the previous desktop, else the one after the current, else the first.
    func initialSelection(in spaces: [Space]) -> Int {
        let current = spaces.first(where: \.isCurrent)
        if let id = previous(current: current?.id, existing: Set(spaces.map(\.id))),
           let row = spaces.firstIndex(where: { $0.id == id }) {
            return row
        }
        guard let currentRow = spaces.firstIndex(where: \.isCurrent) else { return 0 }
        return (currentRow + 1) % spaces.count
    }
}
