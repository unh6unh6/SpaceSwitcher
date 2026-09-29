import SwiftUI

@main
struct SpaceSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Settings UI arrives in Phase 5.
        Settings {
            EmptyView()
        }
    }
}
