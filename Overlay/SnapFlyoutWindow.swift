import Cocoa

final class SnapFlyoutWindow: NSPanel {

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

    init(layouts: [AnyLayoutTemplate] = builtInLayouts) {
        let size = NSSize(width: 560, height: 190)
        self.flyoutView = SnapFlyoutView(
            frame: NSRect(origin: .zero, size: size),
            layouts: layouts
        )

        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // .screenSaver (1000) sits well above .floating (3) where the snap
        // preview lives. popUpMenu (101) was technically higher already, but
        // Spaces-level interactions made it look like the preview was on top
        // in some configurations. screenSaver is uncontestable.
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .stationary, .fullScreenAuxiliary]
        contentView = flyoutView
    }

    func show(on screen: NSScreen) {
        let sv = screen.visibleFrame
        let point = NSPoint(x: sv.midX, y: sv.maxY - 80)
        show(on: screen, near: point)
    }

    func show(on screen: NSScreen, near point: NSPoint) {
        let sv = screen.visibleFrame
        let margin: CGFloat = 18
        let x = min(max(point.x - frame.width / 2, sv.minX + margin), sv.maxX - frame.width - margin)
        let aboveY = point.y + 8
        let belowY = point.y - frame.height - 8
        let preferredY = aboveY + frame.height <= sv.maxY - margin ? aboveY : belowY
        let y = min(max(preferredY, sv.minY + margin), sv.maxY - frame.height - margin)
        setFrameOrigin(NSPoint(x: x, y: y))
        // Always reassert front ordering — the preview window may have been
        // shown more recently, and within the same Space the window server
        // can reorder siblings even across levels in edge cases.
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

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class SnapFlyoutView: NSView {

    private let layouts: [AnyLayoutTemplate]
    private var hoveredZone: SnapFlyoutWindow.ZoneHit?
    private var zoneFrames: [(layout: AnyLayoutTemplate, zone: LayoutZone, rect: NSRect)] = []
    private let columns = 3
    private let titleHeight: CGFloat = 46
    private let sidePadding: CGFloat = 14
    private let bottomPadding: CGFloat = 14
    private let cardSpacing: CGFloat = 10

    init(frame: NSRect, layouts: [AnyLayoutTemplate]) {
        self.layouts = layouts
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
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

        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 16, yRadius: 16)
        // Near-opaque so the preview tint behind it doesn't bleed through —
        // the flyout must read as solidly above the snap preview.
        NSColor.windowBackgroundColor.withAlphaComponent(0.98).setFill()
        bgPath.fill()
        NSColor.separatorColor.withAlphaComponent(0.35).setStroke()
        bgPath.lineWidth = 1
        bgPath.stroke()

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let titleStr = NSAttributedString(string: "Snap Layouts", attributes: titleAttrs)
        titleStr.draw(at: NSPoint(x: 20, y: bounds.height - 30))

        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        NSAttributedString(string: "Release over a card region to place this window", attributes: subtitleAttrs)
            .draw(at: NSPoint(x: 118, y: bounds.height - 27))

        for card in layoutCards() {
            let layoutHover = hoveredZone?.layoutID == card.layout.id
            let cardPath = NSBezierPath(roundedRect: card.rect, xRadius: 10, yRadius: 10)
            (layoutHover ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.quaternaryLabelColor.withAlphaComponent(0.22)).setFill()
            cardPath.fill()
            (layoutHover ? NSColor.controlAccentColor.withAlphaComponent(0.55) : NSColor.separatorColor.withAlphaComponent(0.35)).setStroke()
            cardPath.lineWidth = layoutHover ? 1.5 : 1
            cardPath.stroke()

            NSColor.textBackgroundColor.withAlphaComponent(0.45).setFill()
            NSBezierPath(roundedRect: card.previewRect, xRadius: 7, yRadius: 7).fill()

            for entry in zoneFrames where entry.layout.id == card.layout.id {
                let isHover = hoveredZone?.layoutID == entry.layout.id && hoveredZone?.zoneID == entry.zone.id
                let visualRect = entry.rect.insetBy(dx: 2, dy: 2)
                let fill = isHover
                    ? NSColor.controlAccentColor.withAlphaComponent(0.82)
                    : NSColor.controlAccentColor.withAlphaComponent(0.22)
                fill.setFill()
                let zonePath = NSBezierPath(roundedRect: visualRect, xRadius: 4, yRadius: 4)
                zonePath.fill()
                NSColor.controlAccentColor.withAlphaComponent(isHover ? 0.95 : 0.45).setStroke()
                zonePath.lineWidth = isHover ? 1.5 : 1
                zonePath.stroke()
            }

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            let nameStr = NSAttributedString(string: card.layout.name, attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: NSPoint(x: card.rect.midX - nameSize.width / 2, y: card.rect.minY + 8))
        }
    }

    private func refreshZoneFrames() {
        zoneFrames.removeAll(keepingCapacity: true)
        for card in layoutCards() {
            for zone in card.layout.zones {
                let rect = NSRect(
                    x: card.previewRect.minX + zone.unitRect.minX * card.previewRect.width,
                    y: card.previewRect.minY + zone.unitRect.minY * card.previewRect.height,
                    width: zone.unitRect.width * card.previewRect.width,
                    height: zone.unitRect.height * card.previewRect.height
                )
                zoneFrames.append((card.layout, zone, rect))
            }
        }
    }

    private func layoutCards() -> [(layout: AnyLayoutTemplate, rect: NSRect, previewRect: NSRect)] {
        let rows = max(1, Int(ceil(Double(layouts.count) / Double(columns))))
        let availableWidth = bounds.width - sidePadding * 2 - CGFloat(columns - 1) * cardSpacing
        let availableHeight = bounds.height - titleHeight - bottomPadding - CGFloat(rows - 1) * cardSpacing
        let cardWidth = floor(availableWidth / CGFloat(columns))
        let cardHeight = floor(availableHeight / CGFloat(rows))

        return layouts.enumerated().map { index, layout in
            let row = index / columns
            let col = index % columns
            let x = sidePadding + CGFloat(col) * (cardWidth + cardSpacing)
            let y = bottomPadding + CGFloat(rows - row - 1) * (cardHeight + cardSpacing)
            let rect = NSRect(x: x, y: y, width: cardWidth, height: cardHeight)
            let previewRect = NSRect(x: rect.minX + 10, y: rect.minY + 26, width: rect.width - 20, height: rect.height - 38)
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
