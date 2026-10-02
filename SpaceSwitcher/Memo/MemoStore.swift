import Foundation

/// Desktop memos as Markdown files in a folder the user picks (#18). One file per desktop, linked by
/// the `space:` front matter (`MemoFormat`), named after the desktop. Files without that key are
/// someone else's notes and are never touched.
final class MemoStore {
    static let didChange = Notification.Name("MemoStore.didChange")

    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SpaceSwitcher/Memos", isDirectory: true)
    }

    private struct Entry {
        let url: URL
        let body: String
        let otherFrontMatter: [String]
        let modified: Date
    }

    private(set) var directory: URL
    private var entries: [String: Entry] = [:]
    private var watcher: DispatchSourceFileSystemObject?
    private var watchedPath: String?
    private let fileManager = FileManager.default

    init(directory: URL = MemoStore.defaultDirectory) {
        self.directory = directory
        reload()
    }

    deinit { watcher?.cancel() }

    func memo(for spaceID: String) -> String? {
        entries[spaceID]?.body
    }

    func hasAnyMemo(among spaceIDs: Set<String>) -> Bool {
        entries.keys.contains(where: spaceIDs.contains)
    }

    /// Writes the memo; an empty text deletes the file.
    func setMemo(_ text: String, for spaceID: String, desktopName: String) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = entries[spaceID]
        guard body != (existing?.body ?? "") else { return }

        if body.isEmpty {
            if let url = existing?.url { try? fileManager.removeItem(at: url) }
        } else {
            let url = existing?.url ?? directory.appendingPathComponent(
                MemoFormat.fileName(for: desktopName, taken: Set(markdownFiles().map(\.lastPathComponent))))
            write(MemoFormat.serialize(spaceID: spaceID, body: body, keeping: existing?.otherFrontMatter ?? []), to: url)
        }
        reloadAndNotify()
    }

    /// Follows a desktop rename so the file name stays recognizable. No-op without a memo.
    func renameFile(for spaceID: String, to desktopName: String) {
        guard let entry = entries[spaceID] else { return }
        let others = Set(markdownFiles().map(\.lastPathComponent)).subtracting([entry.url.lastPathComponent])
        let name = MemoFormat.fileName(for: desktopName, taken: others)
        guard name != entry.url.lastPathComponent else { return }
        try? fileManager.moveItem(at: entry.url, to: directory.appendingPathComponent(name))
        reloadAndNotify()
    }

    func changeDirectory(to newDirectory: URL, moveExisting: Bool) {
        guard newDirectory.standardizedFileURL != directory.standardizedFileURL else { return }
        try? fileManager.createDirectory(at: newDirectory, withIntermediateDirectories: true)
        if moveExisting {
            for entry in entries.values {
                let taken = Set(((try? fileManager.contentsOfDirectory(atPath: newDirectory.path)) ?? []))
                let name = MemoFormat.fileName(for: entry.url.deletingPathExtension().lastPathComponent, taken: taken)
                try? fileManager.moveItem(at: entry.url, to: newDirectory.appendingPathComponent(name))
            }
        }
        directory = newDirectory
        reloadAndNotify()
    }

    /// One-time move of #17's names.json descriptions into files; existing memos win.
    func importLegacy(_ descriptions: [String: String], desktopName: (String) -> String) {
        for (spaceID, text) in descriptions where entries[spaceID] == nil {
            setMemo(text, for: spaceID, desktopName: desktopName(spaceID))
        }
    }

    /// Re-reads the folder. Called by the watcher, and cheap enough to call before showing memos.
    func reload() {
        var found: [String: Entry] = [:]
        for url in markdownFiles() {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            let parsed = MemoFormat.parse(text)
            guard let spaceID = parsed.spaceID else { continue }
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            // Two files claiming one desktop (e.g. a copy): the newest wins.
            if let other = found[spaceID], other.modified > modified { continue }
            found[spaceID] = Entry(url: url, body: parsed.body, otherFrontMatter: parsed.otherFrontMatter, modified: modified)
        }
        entries = found
        watchDirectory()
    }

    private func reloadAndNotify() {
        reload()
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    private func markdownFiles() -> [URL] {
        let urls = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey],
                                                         options: [.skipsHiddenFiles])) ?? []
        return urls.filter { $0.pathExtension.lowercased() == MemoFormat.fileExtension }
    }

    private func write(_ text: String, to url: URL) {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSLog("SpaceSwitcher: failed to save memo \(url.lastPathComponent): \(error)")
        }
    }

    /// Editors usually save by writing a new file and renaming it, which changes the directory;
    /// watch that so edits made in MarkEdit, Obsidian, etc. show up immediately.
    private func watchDirectory() {
        let path = directory.path
        if watcher != nil, watchedPath == path { return }
        watcher?.cancel()
        watcher = nil
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { watchedPath = nil; return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .delete],
                                                               queue: .main)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let before = entries.mapValues(\.body)
            reload()
            if entries.mapValues(\.body) != before {
                NotificationCenter.default.post(name: Self.didChange, object: self)
            }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        watcher = source
        watchedPath = path
    }
}
