import Foundation

/// Unsaved overlay edits parked per desktop (#26). Leaving a desktop mid-edit shows the next desktop's
/// memo normally; coming back reopens the editor with the text as it was. In memory only. Pure.
struct MemoDrafts {
    private var texts: [String: String] = [:]

    mutating func park(_ text: String, for spaceID: String) {
        texts[spaceID] = text
    }

    /// The parked draft for this desktop, removed because it goes back into the editor.
    mutating func take(for spaceID: String) -> String? {
        texts.removeValue(forKey: spaceID)
    }

    /// Drafts whose desktop no longer exists, removed so they can be handed back once.
    mutating func takeOrphans(keeping ids: Set<String>) -> [String] {
        let gone = texts.keys.filter { !ids.contains($0) }.sorted()
        return gone.compactMap { texts.removeValue(forKey: $0) }
    }
}
