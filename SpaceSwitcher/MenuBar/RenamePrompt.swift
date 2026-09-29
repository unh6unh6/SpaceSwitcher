import AppKit

/// Modal text prompt for naming a desktop (menu bar entry point; the switcher panel edits inline in Phase 4).
enum RenamePrompt {
    /// Returns the entered text, or nil if cancelled. Validation (trim/cap/empty) is NameStore's job.
    static func run(for space: Space, currentName: String?) -> String? {
        // Agent apps (LSUIElement) are never frontmost on their own; without this the field gets no keys.
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "데스크탑 \(space.index) 이름"
        alert.informativeText = "비워 두면 이름이 지워집니다. 최대 \(NameStore.maxLength)자."
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.stringValue = currentName ?? ""
        field.placeholderString = "데스크탑 \(space.index)"
        alert.accessoryView = field
        alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "취소")
        alert.window.initialFirstResponder = field

        return alert.runModal() == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
