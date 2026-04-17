import Cocoa

enum ScreenManager {

    /// Find the screen whose frame contains the given Quartz point.
    static func screen(containing point: CGPoint) -> NSScreen? {
        // NSScreen.frame is in AppKit coords (bottom-left origin).
        // Convert the Quartz point to AppKit coords for comparison.
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        let appKitPoint = CGPoint(x: point.x, y: mainHeight - point.y)
        return NSScreen.screens.first { NSPointInRect(appKitPoint, $0.frame) }
    }

    /// Convert an NSScreen.visibleFrame rect (AppKit: bottom-left origin, Y up)
    /// to Quartz/AX coordinates (top-left of main screen, Y down).
    static func toQuartz(_ appKitRect: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: appKitRect.minX,
            y: mainHeight - appKitRect.minY - appKitRect.height,
            width: appKitRect.width,
            height: appKitRect.height
        )
    }

    /// Convert a Quartz rect to AppKit screen coordinates.
    static func toAppKit(_ quartzRect: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: quartzRect.minX,
            y: mainHeight - quartzRect.minY - quartzRect.height,
            width: quartzRect.width,
            height: quartzRect.height
        )
    }

    /// Compute the Quartz-coordinate target frame for a snap zone on a given screen.
    static func frame(for zone: SnapZone, on screen: NSScreen) -> CGRect? {
        let v = screen.visibleFrame  // AppKit coords
        switch zone {
        case .leftHalf:    return toQuartz(CGRect(x: v.minX,          y: v.minY, width: v.width / 2,  height: v.height))
        case .rightHalf:   return toQuartz(CGRect(x: v.midX,          y: v.minY, width: v.width / 2,  height: v.height))
        case .topHalf:     return toQuartz(CGRect(x: v.minX,          y: v.midY, width: v.width,      height: v.height / 2))
        case .bottomHalf:  return toQuartz(CGRect(x: v.minX,          y: v.minY, width: v.width,      height: v.height / 2))
        case .topLeft:     return toQuartz(CGRect(x: v.minX,          y: v.midY, width: v.width / 2,  height: v.height / 2))
        case .topRight:    return toQuartz(CGRect(x: v.midX,          y: v.midY, width: v.width / 2,  height: v.height / 2))
        case .bottomLeft:  return toQuartz(CGRect(x: v.minX,          y: v.minY, width: v.width / 2,  height: v.height / 2))
        case .bottomRight: return toQuartz(CGRect(x: v.midX,          y: v.minY, width: v.width / 2,  height: v.height / 2))
        case .full:        return toQuartz(v)
        case .none:        return nil
        }
    }

    /// The screen containing the majority of the given Quartz-coordinate window frame.
    static func bestScreen(for quartzFrame: CGRect) -> NSScreen {
        let appKitFrame = toAppKit(quartzFrame)
        return NSScreen.screens.max(by: {
            $0.frame.intersection(appKitFrame).area < $1.frame.intersection(appKitFrame).area
        }) ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

private extension CGRect {
    var area: CGFloat { width * height }
}
