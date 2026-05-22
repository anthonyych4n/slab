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

struct LeftTwoThirdsRightThird: LayoutTemplate {
    let id   = "rightThird"
    let name = "⅔ | ⅓"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "left",  label: "Left",  unitRect: CGRect(x: 0.0,       y: 0, width: 2.0/3, height: 1.0)),
        LayoutZone(id: "right", label: "Right", unitRect: CGRect(x: 2.0/3,     y: 0, width: 1.0/3, height: 1.0)),
    ]
}

struct LeftThirtyRightSeventy: LayoutTemplate {
    let id   = "leftThirty"
    let name = "30 | 70"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "left",  label: "Left",  unitRect: CGRect(x: 0.0, y: 0, width: 0.3, height: 1.0)),
        LayoutZone(id: "right", label: "Right", unitRect: CGRect(x: 0.3, y: 0, width: 0.7, height: 1.0)),
    ]
}

struct LeftSeventyRightThirty: LayoutTemplate {
    let id   = "rightThirty"
    let name = "70 | 30"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "left",  label: "Left",  unitRect: CGRect(x: 0.0, y: 0, width: 0.7, height: 1.0)),
        LayoutZone(id: "right", label: "Right", unitRect: CGRect(x: 0.7, y: 0, width: 0.3, height: 1.0)),
    ]
}

struct TopBottomHalves: LayoutTemplate {
    let id   = "topBottom"
    let name = "Top | Bottom"
    let icon = "rectangle.split.1x2"
    let zones = [
        LayoutZone(id: "top",    label: "Top",    unitRect: CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.5)),
        LayoutZone(id: "bottom", label: "Bottom", unitRect: CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.5)),
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

struct MainLeftTwoRight: LayoutTemplate {
    let id   = "mainLeftTwoRight"
    let name = "Main + 2"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "main",        label: "Main",        unitRect: CGRect(x: 0.0,       y: 0.0, width: 2.0/3, height: 1.0)),
        LayoutZone(id: "topRight",    label: "Top Right",   unitRect: CGRect(x: 2.0/3,     y: 0.5, width: 1.0/3, height: 0.5)),
        LayoutZone(id: "bottomRight", label: "Bottom Right", unitRect: CGRect(x: 2.0/3,     y: 0.0, width: 1.0/3, height: 0.5)),
    ]
}

struct TwoLeftMainRight: LayoutTemplate {
    let id   = "twoLeftMainRight"
    let name = "2 + Main"
    let icon = "rectangle.split.2x1"
    let zones = [
        LayoutZone(id: "topLeft",    label: "Top Left",    unitRect: CGRect(x: 0.0,     y: 0.5, width: 1.0/3, height: 0.5)),
        LayoutZone(id: "bottomLeft", label: "Bottom Left", unitRect: CGRect(x: 0.0,     y: 0.0, width: 1.0/3, height: 0.5)),
        LayoutZone(id: "main",       label: "Main",        unitRect: CGRect(x: 1.0/3,   y: 0.0, width: 2.0/3, height: 1.0)),
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

/// Curated subset shown in the drag-to-edge flyout. Six is the sweet spot:
/// big enough to cover the common layouts, small enough that the chooser
/// stays glanceable and the cards have enough room to render usable previews.
/// The full list lives in `builtInLayouts` (used by the Layout Picker).
let flyoutLayouts: [AnyLayoutTemplate] = [
    AnyLayoutTemplate(LeftRightHalves()),
    AnyLayoutTemplate(TopBottomHalves()),
    AnyLayoutTemplate(QuadGrid()),
    AnyLayoutTemplate(ThreeColumns()),
    AnyLayoutTemplate(MainSidebar()),
    AnyLayoutTemplate(FullScreenLayout()),
]

/// All built-in layouts in display order.
///
/// Ordered roughly by frequency-of-use on landscape monitors. Orientation-aware
/// presentation lives in the picker / flyout layer — this list stays canonical.
let builtInLayouts: [AnyLayoutTemplate] = [
    AnyLayoutTemplate(LeftRightHalves()),
    AnyLayoutTemplate(LeftThirdRightTwoThirds()),
    AnyLayoutTemplate(LeftTwoThirdsRightThird()),
    AnyLayoutTemplate(ThreeColumns()),
    AnyLayoutTemplate(MainSidebar()),
    AnyLayoutTemplate(QuadGrid()),
    AnyLayoutTemplate(MainLeftTwoRight()),
    AnyLayoutTemplate(TwoLeftMainRight()),
    AnyLayoutTemplate(TopBottomHalves()),
    AnyLayoutTemplate(LeftThirtyRightSeventy()),
    AnyLayoutTemplate(LeftSeventyRightThirty()),
    AnyLayoutTemplate(FullScreenLayout()),
]
