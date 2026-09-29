// Phase 0 spike: dump CGSCopyManagedDisplaySpaces + active space as JSON.
// Run: swift spike/spaces.swift
import Foundation
import CoreGraphics

typealias CGSConnectionID = Int32
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID
@_silgen_name("CGSCopyManagedDisplaySpaces")
func CGSCopyManagedDisplaySpaces(_ cid: CGSConnectionID) -> CFArray
@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> Int

let cid = CGSMainConnectionID()
let displays = CGSCopyManagedDisplaySpaces(cid) as! [[String: Any]]
let active = CGSGetActiveSpace(cid)

// Keep only JSON-safe scalars so the raw structure is visible.
func clean(_ v: Any) -> Any {
    switch v {
    case let d as [String: Any]: return d.mapValues(clean)
    case let a as [Any]: return a.map(clean)
    case let s as String: return s
    case let n as NSNumber: return n
    default: return String(describing: type(of: v))
    }
}

let out: [String: Any] = ["activeSpace": active, "displays": clean(displays)]
let data = try! JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
print(String(data: data, encoding: .utf8)!)
