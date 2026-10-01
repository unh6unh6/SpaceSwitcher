import AppKit

/// Reads the live window list for `SpaceApps` (#14). Keyed by `Space.managedID`.
enum SpaceAppsProvider {
    private static let allSpacesMask: Int32 = 7

    static func current() -> [Int: [SpaceApps.App]] {
        let info = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let windows: [SpaceApps.Window] = info.compactMap { w in
            guard let id = w[kCGWindowNumber as String] as? Int,
                  let pid = w[kCGWindowOwnerPID as String] as? Int32,
                  let bounds = w[kCGWindowBounds as String] as? [String: Double] else { return nil }
            return SpaceApps.Window(id: id, pid: pid, appName: w[kCGWindowOwnerName as String] as? String ?? "",
                                    layer: w[kCGWindowLayer as String] as? Int ?? -1,
                                    width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
        }
        let cid = CGSMainConnectionID()
        var regular: [Int32: Bool] = [:]
        return SpaceApps.group(windows, spacesOf: { id in
            CGSCopySpacesForWindows(cid, allSpacesMask, [id] as CFArray) as? [Int] ?? []
        }, isRegularApp: { pid in
            if let known = regular[pid] { return known }
            let value = NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
            regular[pid] = value
            return value
        })
    }
}
