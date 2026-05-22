import Cocoa

final class SnapFlyoutWindow: NSPanel {

    /// Which screen edge the cursor crossed to open the flyout. The flyout
    /// anchors itself flush against this edge so the cursor can drag from the
    /// hot-zone into the flyout without traversing a dead gap.
    enum Anchor {
        case top, left, right
    }

    struct ZoneHit: Equatable {
        let layoutID: String
        let zoneID: String
        let layout: AnyLayoutTemplate
        let zone: LayoutZone

        static func == (lhs: ZoneHit, rhs: ZoneHit) -> Bool {
            lhs.layoutID == rhs.layoutID && lhs.zoneID == rhs.zoneID
        }
    }

    private let flyoutView: SnapFlyoutView

    init(layouts: [AnyLayoutTemplate] = flyoutLayouts) {
        // Layout-driven sizing. With 6 cards in 3 columns × 2 rows we want
        // each card ~168×96 — that leaves ~52 px tall for the preview inside,
        // big enough to render even Main+Sidebar legibly.
        let columns = 3
        let rows = max(1, Int(ceil(Double(layouts.count) / Double(columns))))
        let cardWidth: CGFloat = 168
        let cardHeight: CGFloat = 96
        let sidePadding: CGFloat = 14
        let topBar: CGFloat = 36          // compact title row
        let bottomPadding: CGFloat = 14
        let cardSpacing: CGFloat = 10
        let width  = sidePadding * 2 + CGFloat(columns) * cardWidth + CGFloat(columns - 1) * cardSpacing
        let height = topBar + bottomPadding + CGFloat(rows) * cardHeight + CGFloat(rows - 1) * cardSpacing
        let size = NSSize(width: width, height: height)

        self.flyoutView = SnapFlyoutView(
            frame: NSRect(origin: .zero, size: size),
            layouts: layouts,
            topBar: topBar,
            sidePadding: sidePadding,
            bottomPadding: bottomPadding,
            cardSpacing: cardSpacing,
            columns: columns
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // .screenSaver (1000) sits well above the snap preview's .floating (3).
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        // Rely on the visual-effect view inside SnapFlyoutView for the shadow
        // and rounded corners, not NSWindow's automatic shadow.
        hasShadow = true
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .stationary, .fullScreenAuxiliary]
        contentView = flyoutView
    }

    /// Show the flyout anchored to the given screen edge.
    ///
    /// We pin one of the flyout's edges flush against the screen edge so
    /// there's no dead gap between the snap hot-zone and the chooser — the
    /// cursor can travel from the edge into the flyout in one continuous
    /// motion. On the perpendicular axis we center the flyout on the cursor
    /// (clamped to the visible frame) so it feels attached to the drag.
    func show(on screen: NSScreen, anchor: Anchor, cursor: NSPoint) {
        let sv = screen.visibleFrame
        let inset: CGFloat = 4
        var x: CGFloat = sv.midX - frame.width / 2
        var y: CGFloat = sv.maxY - frame.height - inset
        switch anchor {
        case .top:
            x = clamp(cursor.x - frame.width / 2, sv.minX + inset, sv.maxX - frame.width - inset)
            y = sv.maxY - frame.height - inset
        case .left:
            x = sv.minX + inset
            y = clamp(cursor.y - frame.height / 2, sv.minY + inset, sv.maxY - frame.height - inset)
        case .right:
            x = sv.maxX - frame.width - inset
            y = clamp(cursor.y - frame.height / 2, sv.minY + inset, sv.maxY - frame.height - inset)
        }
        setFrameOrigin(NSPoint(x: x, y: y))
        // Always reassert front order — the preview may have been ordered
        // front more recently, and within the same Space the window server
        // can re-sort siblings even across levels in edge cases.
        alphaValue = 1
        orderFrontRegardless()
    }

    func hide() {
        guard isVisible else { return }
        flyoutView.setHoveredZone(nil)
        orderOut(nil)
    }

    func zoneAt(screenPoint: NSPoint) -> ZoneHit? {
        guard isVisible, frame.contains(screenPoint) else { return nil }
        let local = NSPoint(
            x: screenPoint.x - frame.origin.x,
            y: screenPoint.y - frame.origin.y
        )
        return flyoutView.zoneAt(localPoint: local)
    }

    func updateHover(screenPoint: NSPoint) {
        guard isVisible else { return }
        flyoutView.setHoveredZone(zoneAt(screenPoint: screenPoint))
    }

    func containsScreenPoint(_ point: NSPoint) -> Bool {
        return isVisible && frame.contains(point)
    }

    /// Sticky hit test — `containsScreenPoint` with a 24 px outward margin.
    /// Used by the snap detector to decide whether to keep the flyout alive:
    /// brief cursor jitter at the edge of the flyout (or in the corridor
    /// between the snap hot-zone and the flyout) shouldn't dismiss the chooser.
    /// This is the macOS analog of Windows 11's "safe triangle" corridor.
    func containsScreenPointSticky(_ point: NSPoint) -> Bool {
        guard isVisible else { return false }
        return frame.insetBy(dx: -24, dy: -24).contains(point)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        max(lo, min(hi, v))
    }
}

// MARK: - Flyout content

final class SnapFlyoutView: NSView {

    private let layouts: [AnyLayoutTemplate]
    private var hoveredZone: SnapFlyoutWindow.ZoneHit?
    private var zoneFrames: [(layout: AnyLayoutTemplate, zone: LayoutZone, rect: NSRect)] = []

    // Geometry passed in from the window so card sizing is consistent with
    // the window's calculated size — no risk of negative card heights when
    // counts change.
    private let topBar: CGFloat
    private let sidePadding: CGFloat
    private let bottomPadding: CGFloat
    private let cardSpacing: CGFloat
    private let columns: Int

    /// Background visual-effect view — `.menu` material matches the Sequoia
    /// green-button hover menu, which is the closest macOS precedent for what
    /// we're building. `.behindWindow` blend so the desktop / windows behind
    /// show through subtly.
    private let blurView: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .menu
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 12
        v.layer?.cornerCurve = .continuous
        v.layer?.masksToBounds = true
        v.layer?.borderWidth = 0.5
        v.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        return v
    }()

    init(frame: NSRect,
         layouts: [AnyLayoutTemplate],
         topBar: CGFloat,
         sidePadding: CGFloat,
         bottomPadding: CGFloat,
         cardSpacing: CGFloat,
         columns: Int) {
        self.layouts = layouts
        self.topBar = topBar
        self.sidePadding = sidePadding
        self.bottomPadding = bottomPadding
        self.cardSpacing = cardSpacing
        self.columns = columns
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        addSubview(blurView)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setHoveredZone(_ hit: SnapFlyoutWindow.ZoneHit?) {
        if hit == hoveredZone { return }
        hoveredZone = hit
        needsDisplay = true
    }

    func zoneAt(localPoint: NSPoint) -> SnapFlyoutWindow.ZoneHit? {
        refreshZoneFrames()
        for entry in zoneFrames where entry.rect.contains(localPoint) {
            return SnapFlyoutWindow.ZoneHit(
                layoutID: entry.layout.id,
                zoneID: entry.zone.id,
                layout: entry.layout,
                zone: entry.zone
            )
        }
        // If the user is over a card but not over a specific zone (gutter
        // between cells), default to the nearest zone in that card. Makes
        // the hit-testing forgiving on small zones.
        if let card = layoutCards().first(where: { $0.rect.contains(localPoint) }),
           let nearest = nearestZone(to: localPoint, in: card.layout) {
            return SnapFlyoutWindow.ZoneHit(
                layoutID: card.layout.id,
                zoneID: nearest.id,
                layout: card.layout,
                zone: nearest
            )
        }
        return nil
    }

    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        refreshZoneFrames()

        // Title row — single short label, no subtitle. Compact and quiet so
        // the cards do the talking.
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let titleStr = NSAttributedString(string: "Snap Layouts", attributes: titleAttrs)
        titleStr.draw(at: NSPoint(x: sidePadding + 4, y: bounds.height - topBar + (topBar - 18) / 2))

        for card in layoutCards() {
            let layoutHover = hoveredZone?.layoutID == card.layout.id
            let cardPath = NSBezierPath(roundedRect: card.rect, xRadius: 8, yRadius: 8)
            (layoutHover ? NSColor.controlAccentColor.withAlphaComponent(0.10) : NSColor.quaternaryLabelColor.withAlphaComponent(0.18)).setFill()
            cardPath.fill()
            (layoutHover ? NSColor.controlAccentColor.withAlphaComponent(0.45) : NSColor.separatorColor.withAlphaComponent(0.35)).setStroke()
            cardPath.lineWidth = layoutHover ? 1.0 : 0.75
            cardPath.stroke()

            // Each zone drawn inside the preview rect using the same Y-up
            // coordinate flip the picker uses, so they stay visually
            // consistent across the app.
            for entry in zoneFrames where entry.layout.id == card.layout.id {
                let isHover = hoveredZone?.layoutID == entry.layout.id && hoveredZone?.zoneID == entry.zone.id
                let visualRect = entry.rect.insetBy(dx: 1.5, dy: 1.5)
                let fill = isHover
                    ? NSColor.controlAccentColor.withAlphaComponent(0.75)
                    : NSColor.controlAccentColor.withAlphaComponent(0.18)
                fill.setFill()
                let zonePath = NSBezierPath(roundedRect: visualRect, xRadius: 3, yRadius: 3)
                zonePath.fill()
                NSColor.controlAccentColor.withAlphaComponent(isHover ? 0.85 : 0.40).setStroke()
                zonePath.lineWidth = isHover ? 1.2 : 0.75
                zonePath.stroke()
            }

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.labelColor.withAlphaComponent(0.85)
            ]
            let nameStr = NSAttributedString(string: card.layout.name, attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: NSPoint(x: card.rect.midX - nameSize.width / 2, y: card.rect.minY + 6))
        }
    }

    // MARK: - Geometry helpers

    private func refreshZoneFrames() {
        zoneFrames.removeAll(keepingCapacity: true)
        for card in layoutCards() {
            for zone in card.layout.zones {
                // unitRect uses Y-up; the card's previewRect is in this view's
                // (Y-up) coordinate space, so no flip is needed here — the
                // top of the unit rect maps to the top of the preview rect.
                let rect = NSRect(
                    x: card.previewRect.minX + zone.unitRect.minX * card.previewRect.width,
                    y: card.previewRect.minY + zone.unitRect.minY * card.previewRect.height,
                    width:  zone.unitRect.width  * card.previewRect.width,
                    height: zone.unitRect.height * card.previewRect.height
                )
                zoneFrames.append((card.layout, zone, rect))
            }
        }
    }

    private func layoutCards() -> [(layout: AnyLayoutTemplate, rect: NSRect, previewRect: NSRect)] {
        let rows = max(1, Int(ceil(Double(layouts.count) / Double(columns))))
        let availableWidth  = bounds.width  - sidePadding * 2 - CGFloat(columns - 1) * cardSpacing
        let availableHeight = bounds.height - topBar - bottomPadding - CGFloat(rows - 1) * cardSpacing
        let cardWidth  = floor(availableWidth  / CGFloat(columns))
        let cardHeight = floor(availableHeight / CGFloat(rows))

        return layouts.enumerated().map { index, layout in
            let row = index / columns
            let col = index % columns
            let x = sidePadding + CGFloat(col) * (cardWidth + cardSpacing)
            // Y from bottom (this view isn't flipped) → flip row index.
            let y = bottomPadding + CGFloat(rows - row - 1) * (cardHeight + cardSpacing)
            let rect = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
            // Reserve ~18 px at the bottom of the card for the name label,
            // 8 px of padding around the preview itself.
            let previewRect = NSRect(
                x: rect.minX + 8,
                y: rect.minY + 22,
                width:  max(0, rect.width  - 16),
                height: max(0, rect.height - 30)
            )
            return (layout, rect, previewRect)
        }
    }

    private func nearestZone(to point: NSPoint, in layout: AnyLayoutTemplate) -> LayoutZone? {
        let candidates = zoneFrames.filter { $0.layout.id == layout.id }
        return candidates.min { lhs, rhs in
            lhs.rect.centerDistance(to: point) < rhs.rect.centerDistance(to: point)
        }?.zone
    }
}

private extension NSRect {
    func centerDistance(to point: NSPoint) -> CGFloat {
        let dx = midX - point.x
        let dy = midY - point.y
        return hypot(dx, dy)
    }
}
