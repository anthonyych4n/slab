import Cocoa

/// One rectangular region within a screen layout, expressed as fractions (0–1) of the visible frame.
struct LayoutZone: Identifiable, Hashable, Codable {
    let id: String
    let label: String
    /// x, y, width, height all in 0.0–1.0 range relative to screen.visibleFrame.
    let unitRect: CGRect

    enum CodingKeys: String, CodingKey {
        case id, label, unitX, unitY, unitW, unitH
    }

    init(id: String, label: String, unitRect: CGRect) {
        self.id = id; self.label = label; self.unitRect = unitRect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        let x = try c.decode(CGFloat.self, forKey: .unitX)
        let y = try c.decode(CGFloat.self, forKey: .unitY)
        let w = try c.decode(CGFloat.self, forKey: .unitW)
        let h = try c.decode(CGFloat.self, forKey: .unitH)
        unitRect = CGRect(x: x, y: y, width: w, height: h)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,              forKey: .id)
        try c.encode(label,           forKey: .label)
        try c.encode(unitRect.minX,   forKey: .unitX)
        try c.encode(unitRect.minY,   forKey: .unitY)
        try c.encode(unitRect.width,  forKey: .unitW)
        try c.encode(unitRect.height, forKey: .unitH)
    }
}

protocol LayoutTemplate: Identifiable {
    var id: String { get }
    var name: String { get }
    /// SF Symbol name
    var icon: String { get }
    var zones: [LayoutZone] { get }
}

extension LayoutTemplate {
    /// Compute the AppKit-coordinate (bottom-left origin) frame for a zone on a given screen.
    func appKitFrame(for zone: LayoutZone, on screen: NSScreen) -> CGRect {
        let v = screen.visibleFrame
        return CGRect(
            x: v.minX + zone.unitRect.minX * v.width,
            y: v.minY + zone.unitRect.minY * v.height,
            width:  zone.unitRect.width  * v.width,
            height: zone.unitRect.height * v.height
        )
    }

    /// Compute the Quartz-coordinate frame (top-left origin) suitable for AX operations.
    func quartzFrame(for zone: LayoutZone, on screen: NSScreen) -> CGRect {
        return ScreenManager.toQuartz(appKitFrame(for: zone, on: screen))
    }
}

/// Type-erased wrapper so mixed layout arrays can be used in SwiftUI
struct AnyLayoutTemplate: Identifiable {
    let id: String
    let name: String
    let icon: String
    let zones: [LayoutZone]
    private let _quartzFrame: (LayoutZone, NSScreen) -> CGRect

    init<T: LayoutTemplate>(_ layout: T) {
        id    = layout.id
        name  = layout.name
        icon  = layout.icon
        zones = layout.zones
        _quartzFrame = { layout.quartzFrame(for: $0, on: $1) }
    }

    func quartzFrame(for zone: LayoutZone, on screen: NSScreen) -> CGRect {
        _quartzFrame(zone, screen)
    }
}
