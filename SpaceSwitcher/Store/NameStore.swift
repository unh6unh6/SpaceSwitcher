import Foundation

/// Desktop names keyed by `Space.id` (uuid), persisted as
/// `{ "version": 1, "names": { "<uuid>": "업무" } }` (SPEC §3.4).
/// Names of Spaces that disappear are kept until `removeUnused` is called explicitly,
/// because a Space can be missing from the list only temporarily.
final class NameStore {
    static let didChange = Notification.Name("NameStore.didChange")
    static let maxLength = 30

    static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpaceSwitcher/names.json")
    }

    private struct File: Codable {
        var version = 1
        var names: [String: String] = [:]
    }

    private let fileURL: URL
    private var file = File()

    init(fileURL: URL = NameStore.defaultURL) {
        self.fileURL = fileURL
        load()
    }

    func name(for id: String) -> String? {
        file.names[id]
    }

    /// The user's name, or the "데스크탑 N" fallback shown for unnamed desktops.
    func displayName(for space: Space) -> String {
        name(for: space.id) ?? "데스크탑 \(space.index)"
    }

    /// Trims whitespace and caps at `maxLength` characters; an empty result removes the name.
    func setName(_ raw: String, for id: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = String(trimmed.prefix(Self.maxLength))
        guard file.names[id] != (name.isEmpty ? nil : name) else { return }
        file.names[id] = name.isEmpty ? nil : name
        save()
    }

    /// How many names belong to Spaces not in `ids` (what `removeUnused` would delete).
    func unusedCount(keeping ids: Set<String>) -> Int {
        file.names.keys.filter { !ids.contains($0) }.count
    }

    /// Deletes names whose id is not in `ids`. Returns how many were removed.
    @discardableResult
    func removeUnused(keeping ids: Set<String>) -> Int {
        let unused = file.names.keys.filter { !ids.contains($0) }
        guard !unused.isEmpty else { return 0 }
        unused.forEach { file.names[$0] = nil }
        save()
        return unused.count
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(File.self, from: data) {
            file = decoded
        } else {
            // Keep the unreadable file for recovery instead of overwriting it on the next save.
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("SpaceSwitcher: failed to save names: \(error)")
        }
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
