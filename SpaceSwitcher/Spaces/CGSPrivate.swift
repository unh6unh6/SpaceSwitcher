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
