import Foundation

struct LeftRightHalves: LayoutTemplate {
    let id   = "leftRight"
    let name = "Left | Right"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "left",  label: "Left",  unitRect: CGRect(x: 0.0, y: 0, width: 0.5, height: 1.0)),
        LayoutZone(id: "right", label: "Right", unitRect: CGRect(x: 0.5, y: 0, width: 0.5, height: 1.0)),
    ]
}

struct LeftThirdRightTwoThirds: LayoutTemplate {
    let id   = "leftThird"
    let name = "⅓ | ⅔"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "left",  label: "Left",  unitRect: CGRect(x: 0.0,       y: 0, width: 1.0/3, height: 1.0)),
        LayoutZone(id: "right", label: "Right", unitRect: CGRect(x: 1.0/3,     y: 0, width: 2.0/3, height: 1.0)),
    ]
}

struct ThreeColumns: LayoutTemplate {
    let id   = "threeCol"
    let name = "Three Columns"
    let icon = "rectangle.split.3x1"
    let zones = [
        LayoutZone(id: "left",   label: "Left",   unitRect: CGRect(x: 0.0,   y: 0, width: 1.0/3, height: 1.0)),
        LayoutZone(id: "center", label: "Center", unitRect: CGRect(x: 1.0/3, y: 0, width: 1.0/3, height: 1.0)),
        LayoutZone(id: "right",  label: "Right",  unitRect: CGRect(x: 2.0/3, y: 0, width: 1.0/3, height: 1.0)),
    ]
}

struct QuadGrid: LayoutTemplate {
    let id   = "quad"
    let name = "2 × 2 Grid"
    let icon = "rectangle.grid.2x2"
    let zones = [
        LayoutZone(id: "topLeft",     label: "Top Left",     unitRect: CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.5)),
        LayoutZone(id: "topRight",    label: "Top Right",    unitRect: CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)),
        LayoutZone(id: "bottomLeft",  label: "Bottom Left",  unitRect: CGRect(x: 0.0, y: 0.0, width: 0.5, height: 0.5)),
        LayoutZone(id: "bottomRight", label: "Bottom Right", unitRect: CGRect(x: 0.5, y: 0.0, width: 0.5, height: 0.5)),
    ]
}

struct MainSidebar: LayoutTemplate {
    let id   = "mainSidebar"
    let name = "Main + Sidebar"
    let icon = "sidebar.right"
    let zones = [
        LayoutZone(id: "main",    label: "Main",    unitRect: CGRect(x: 0.0,  y: 0, width: 2.0/3, height: 1.0)),
        LayoutZone(id: "sidebar", label: "Sidebar", unitRect: CGRect(x: 2.0/3, y: 0, width: 1.0/3, height: 1.0)),
    ]
}

struct FullScreenLayout: LayoutTemplate {
    let id   = "fullscreen"
    let name = "Full Screen"
    let icon = "rectangle"
    let zones = [
        LayoutZone(id: "full", label: "Full", unitRect: CGRect(x: 0, y: 0, width: 1, height: 1)),
    ]
}

/// All built-in layouts in display order.
let builtInLayouts: [AnyLayoutTemplate] = [
    AnyLayoutTemplate(LeftRightHalves()),
    AnyLayoutTemplate(LeftThirdRightTwoThirds()),
    AnyLayoutTemplate(ThreeColumns()),
    AnyLayoutTemplate(QuadGrid()),
    AnyLayoutTemplate(MainSidebar()),
    AnyLayoutTemplate(FullScreenLayout()),
]
