import Foundation

/// Unsaved overlay edits per desktop (#26), including the one being typed. Leaving a desktop mid-edit
/// shows the next desktop's memo normally; coming back — or relaunching after a quit or crash —
/// reopens the editor with the text as it was. Persisted under its own UserDefaults key (never in the
/// memo files); `init()` keeps it in memory only.
struct MemoDrafts {
    private var texts: [String: String] = [:]
    private let key: String?
    private let defaults: UserDefaults

    init() {
        key = nil
        defaults = .standard
    }

    init(persistingAs key: String, in defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
        texts = defaults.dictionary(forKey: key) as? [String: String] ?? [:]
    }

    func draft(for spaceID: String) -> String? {
        texts[spaceID]
    }

    mutating func park(_ text: String, for spaceID: String) {
        guard texts[spaceID] != text else { return }
        texts[spaceID] = text
        save()
    }

    /// The edit was saved or cancelled.
    mutating func discard(for spaceID: String) {
        guard texts.removeValue(forKey: spaceID) != nil else { return }
        save()
    }

    /// Drafts whose desktop no longer exists, removed so they can be handed back once.
    mutating func takeOrphans(keeping ids: Set<String>) -> [String] {
        let gone = texts.keys.filter { !ids.contains($0) }.sorted()
        guard !gone.isEmpty else { return [] }
        defer { save() }
        return gone.compactMap { texts.removeValue(forKey: $0) }
    }

    private func save() {
        if let key { defaults.set(texts, forKey: key) }
    }
}
