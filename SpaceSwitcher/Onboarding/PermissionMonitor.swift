import AppKit
import ApplicationServices
import Combine
import Foundation

/// Polls Accessibility trust and the "Switch to Desktop N" shortcuts.
/// Neither has a change notification, so a cheap 1-second timer drives both.
final class PermissionMonitor: ObservableObject {
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    /// Desktop numbers (1...16) whose "Switch to Desktop N" shortcut is off. Those use the slow arrow fallback.
    @Published private(set) var desktopsWithoutShortcut: [Int] = []
    /// The Dock ignored a "Switch to Desktop N" press (#22); switching falls back to Ctrl+←/→.
    @Published private(set) var dockIgnoresShortcuts = SpaceSwitcherService.directShortcutsUnresponsive

    private var timer: Timer?

    init() {
        NotificationCenter.default.addObserver(forName: SpaceSwitcherService.healthDidChange, object: nil, queue: .main) { [weak self] _ in
            self?.dockIgnoresShortcuts = SpaceSwitcherService.directShortcutsUnresponsive
        }

        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
    }

    /// The checks talk to WindowServer and cfprefsd, which can stall; keep them off the main thread (#10).
    private let queue = DispatchQueue(label: "SpaceSwitcher.PermissionMonitor", qos: .utility)
    private var checking = false

    /// A Dock restarted any other way (Terminal `killall Dock`, a crash, logout) also brings the shortcuts
    /// back, so give direct switching another chance instead of staying on slow arrows (#22). NSWorkspace
    /// posts no launch notification for the Dock (checked), so watch its pid on this 1 s tick.
    private var dockPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier

    private func checkDockRestart() {
        let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier
        if let pid, pid != dockPID {
            dockPID = pid
            SpaceSwitcherService.resetHealth()
        }
    }

    func refresh() {
        checkDockRestart()
        guard !checking else { return }  // a stalled check must not pile up a queue of new ones
        checking = true
        queue.async { [weak self] in
            let trusted = AXIsProcessTrusted()
            let hotkeys = SymbolicHotKeys.load()
            let missing = SpaceProvider.spaces().map(\.index).filter { index in
                guard let id = SymbolicHotKeys.desktopID(index) else { return false }
                return hotkeys[id] == nil
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                if trusted != self.isTrusted { self.isTrusted = trusted }
                if missing != self.desktopsWithoutShortcut { self.desktopsWithoutShortcut = missing }
            }
        }
    }

    /// Shows the system "allow Accessibility" prompt (only the first time per app identity).
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
