import Foundation

/// Where an overlay memo edit gets saved (#26). The overlay follows the active desktop, but an edit
/// belongs to the desktop it started on — saving to the desktop on screen at save time overwrote
/// another desktop's memo. Pure.
enum MemoEditTarget: Equatable {
    case save(Space)
    /// The desktop was removed while its memo was being edited.
    case gone
    case nothing

    static func resolve(editing: Space?, in spaces: [Space]) -> MemoEditTarget {
        guard let editing else { return .nothing }
        return spaces.first { $0.id == editing.id }.map(MemoEditTarget.save) ?? .gone
    }

    /// Overlay title while editing, so it is clear which desktop the text will be saved to.
    static func editingTitle(_ desktopName: String) -> String {
        "\(desktopName) (편집 중)"
    }
}
