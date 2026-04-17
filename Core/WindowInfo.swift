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
