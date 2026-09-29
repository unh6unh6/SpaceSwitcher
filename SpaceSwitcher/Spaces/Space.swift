import Foundation

struct Space: Identifiable, Equatable {
    /// Persistent key for names: the Space `uuid`, or `mainKey` when the uuid is empty.
    let id: String
    /// Runtime-only ID (`ManagedSpaceID`). Reassigned on reboot, so never persist it.
    let managedID: Int
    /// 1-based position among regular desktops — the N in "Desktop N".
    let index: Int
    let isCurrent: Bool

    static let mainKey = "__main__"
}

/// Turns the raw `CGSCopyManagedDisplaySpaces` output into regular desktops of the main display.
/// Pure so it can be unit-tested without touching the private API.
enum SpaceParser {
    static let desktopType = 0

    static func parse(_ displays: [[String: Any]], activeSpaceID: Int, mainDisplayID: String?) -> [Space] {
        let display = displays.first { ($0["Display Identifier"] as? String) == mainDisplayID } ?? displays.first
        guard let rawSpaces = display?["Spaces"] as? [[String: Any]] else { return [] }

        let desktops = rawSpaces.filter { ($0["type"] as? Int) == desktopType }
        return desktops.enumerated().compactMap { offset, raw in
            guard let managedID = raw["ManagedSpaceID"] as? Int else { return nil }
            let uuid = raw["uuid"] as? String ?? ""
            return Space(id: uuid.isEmpty ? Space.mainKey : uuid,
                         managedID: managedID,
                         index: offset + 1,
                         isCurrent: managedID == activeSpaceID)
        }
    }
}
