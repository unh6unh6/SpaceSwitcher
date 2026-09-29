import Foundation
import ServiceManagement

/// Login item via `SMAppService.mainApp` (macOS 13+). The system owns the state; we only read and request it.
enum LaunchAtLogin {
    enum Status: Equatable {
        case enabled
        case disabled
        /// Registered, but the user must allow it in System Settings → General → Login Items.
        case needsApproval
    }

    static var status: Status {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .needsApproval
        default: return .disabled
        }
    }

    /// Returns an error message to show, or nil on success.
    static func set(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
