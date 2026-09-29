import ColorSync  // CGDisplayCreateUUIDFromDisplayID
import CoreGraphics
import Foundation

/// Reads the current desktop list. There is no notification for add/remove/reorder,
/// so callers re-query every time a menu or panel opens.
enum SpaceProvider {
    static func spaces() -> [Space] {
        let cid = CGSMainConnectionID()
        let displays = CGSCopyManagedDisplaySpaces(cid) as? [[String: Any]] ?? []
        return SpaceParser.parse(displays, activeSpaceID: CGSGetActiveSpace(cid), mainDisplayID: mainDisplayUUID())
    }

    private static func mainDisplayUUID() -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(CGMainDisplayID())?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
