import CoreGraphics

// Private SkyLight/CoreGraphics API. Declarations live ONLY in this file (CLAUDE.md rule).
// Verified on macOS 27.0.1 — see docs/phase0-findings.md.

typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

/// One dictionary per display: "Display Identifier", "Current Space", "Spaces" ([uuid, type, ManagedSpaceID, id64]).
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> Int

/// Space IDs (`ManagedSpaceID`) a window is on. Mask 7 = current, other and fullscreen Spaces.
/// Verified on macOS 27.0.1 for #14 (per-desktop app icons).
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: Int32, _ windowIDs: CFArray) -> CFArray
