import Foundation

/// Keeps an always-editable memo (#27) and its file in step. The editor saves as you type; the folder
/// watcher reports every change, including our own writes. Compares trimmed text because the store
/// trims what it writes. Pure.
struct MemoSync {
    enum Decision: Equatable {
        /// Our own write, or nothing new.
        case ignore
        /// Changed outside and the editor has nothing unsaved: show the new text.
        case replace
        /// Changed outside while the editor has unsaved typing: keep typing, it is saved next.
        case keepLocal
    }

    /// What the file holds as far as we know (last loaded or saved).
    private var saved: String

    init(loaded: String?) {
        saved = Self.normalized(loaded)
    }

    func needsSave(_ editorText: String) -> Bool {
        Self.normalized(editorText) != saved
    }

    mutating func didSave(_ text: String) {
        saved = Self.normalized(text)
    }

    func incoming(_ fileText: String?, editorText: String) -> Decision {
        let file = Self.normalized(fileText)
        if file == saved { return .ignore }
        return needsSave(editorText) ? .keepLocal : .replace
    }

    private static func normalized(_ text: String?) -> String {
        (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
