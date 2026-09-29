import ApplicationServices
import Combine
import Foundation

/// Polls Accessibility trust and the "Switch to Desktop N" shortcuts.
/// Neither has a change notification, so a cheap 1-second timer drives both.
final class PermissionMonitor: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    /// Desktop numbers (1...16) whose "Switch to Desktop N" shortcut is off. Those use the slow arrow fallback.
    @Published private(set) var desktopsWithoutShortcut: [Int] = []

    private var timer: Timer?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func refresh() {
        let trusted = AXIsProcessTrusted()
        if trusted != isTrusted { isTrusted = trusted }

        let hotkeys = SymbolicHotKeys.load()
        let missing = SpaceProvider.spaces().map(\.index).filter { index in
            guard let id = SymbolicHotKeys.desktopID(index) else { return false }
            return hotkeys[id] == nil
        }
        if missing != desktopsWithoutShortcut { desktopsWithoutShortcut = missing }
    }

    /// Shows the system "allow Accessibility" prompt (only the first time per app identity).
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
