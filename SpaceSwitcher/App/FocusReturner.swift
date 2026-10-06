import AppKit

/// Text fields in our non-activating panels need the app to be active. This borrows the keyboard
/// and later hands it back to whichever app the user was in (#7: not `NSApp.hide`, which would also
/// hide the panel). Shared by the switcher's inline editors and the memo overlay.
final class FocusReturner {
    private var borrowed = false
    private var previous: NSRunningApplication?

    func take(for window: NSWindow) {
        if !borrowed {
            let front = NSWorkspace.shared.frontmostApplication
            previous = front?.processIdentifier == ProcessInfo.processInfo.processIdentifier ? nil : front
        }
        borrowed = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKey()
    }

    /// Lets go without reactivating the previous app: used when the user already moved to another
    /// desktop, where activating an app from the old one would pull them back.
    func release() {
        guard borrowed else { return }
        borrowed = false
        previous = nil
        NSApp.deactivate()
    }

    func giveBack() {
        guard borrowed else { return }
        borrowed = false
        if let app = previous, !app.isTerminated {
            app.activate()
        } else {
            NSApp.deactivate()
        }
        previous = nil
    }
}
