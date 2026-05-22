import Cocoa
import ApplicationServices

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let windowTitle: String
    let appBundleID: String?
    let appIcon: NSImage?
    /// Frame in Quartz screen coordinates (top-left origin of main screen, Y increases downward).
    var frame: CGRect
    var isSnapped: Bool = false
    var preSnapFrame: CGRect?

    // NSImage is not Hashable — exclude from Equatable/Hashable
    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// Snap zone used by SnapDetector and WindowManager
enum SnapZone: Equatable {
    case leftHalf
    case rightHalf
    case topHalf
    case bottomHalf
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case full
    case none
}

extension SnapZone {
    /// Maps a "simple" edge/corner snap to the equivalent multi-zone layout
    /// plus the specific zone that the user filled. Returned tuple is used to
    /// trigger Snap Assist (the per-zone window chooser) after a quick edge
    /// snap, so e.g. snapping a window to the left half automatically offers
    /// to fill the right half.
    ///
    /// `.full` and `.none` return nil — there are no remaining zones to fill.
    var implicitLayoutAndZone: (layout: AnyLayoutTemplate, zone: LayoutZone)? {
        switch self {
        case .leftHalf:
            let l = LeftRightHalves()
            return (AnyLayoutTemplate(l), l.zones[0])  // "left"
        case .rightHalf:
            let l = LeftRightHalves()
            return (AnyLayoutTemplate(l), l.zones[1])  // "right"
        case .topHalf:
            let l = TopBottomHalves()
            return (AnyLayoutTemplate(l), l.zones[0])  // "top"
        case .bottomHalf:
            let l = TopBottomHalves()
            return (AnyLayoutTemplate(l), l.zones[1])  // "bottom"
        case .topLeft, .topRight, .bottomLeft, .bottomRight:
            // Snap into a quadrant of the 2x2 grid layout — assist will offer
            // to fill the other three quadrants.
            let l = QuadGrid()
            let id: String = {
                switch self {
                case .topLeft:     return "topLeft"
                case .topRight:    return "topRight"
                case .bottomLeft:  return "bottomLeft"
                case .bottomRight: return "bottomRight"
                default:           return ""
                }
            }()
            guard let zone = l.zones.first(where: { $0.id == id }) else { return nil }
            return (AnyLayoutTemplate(l), zone)
        case .full, .none:
            return nil
        }
    }
}
