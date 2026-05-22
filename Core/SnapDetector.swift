import Cocoa

final class SnapDetector {

    private enum DragState {
        case idle
        case dragging(window: WindowInfo)
        case inEdgeZone(window: WindowInfo, zone: SnapZone, screen: NSScreen)
        case inFlyoutZone(window: WindowInfo, hit: SnapFlyoutWindow.ZoneHit, screen: NSScreen, frame: CGRect)
    }

    private let windowManager: WindowManager
    private let previewWindow = SnapPreviewWindow()
    private let flyoutWindow  = SnapFlyoutWindow()

    private var state: DragState = .idle
    private var dragStart: CGPoint?

    private var globalMouseDown: Any?
    private var globalMouseDrag: Any?
    private var globalMouseUp: Any?
    private var localMouseDown: Any?
    private var localMouseDrag: Any?
    private var localMouseUp: Any?

    /// Timestamp of the last moment the cursor was inside the flyout's
    /// sticky region or on an edge that would re-open the flyout. Used to
    /// implement a short close-delay so brief jitter between the hot-zone
    /// and the flyout doesn't dismiss the chooser (Windows 11 calls this
    /// pattern a "safe triangle"; we use a time-based grace instead).
    private var lastFlyoutEngagedAt: Date?
    private let flyoutCloseDelay: TimeInterval = 0.35

    private let minDragDistance: CGFloat = 8

    var onDidSnap: ((_ layout: AnyLayoutTemplate,
                     _ zone: LayoutZone,
                     _ window: WindowInfo,
                     _ screen: NSScreen) -> Void)?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func start() {
        let trusted = AXIsProcessTrusted()
        if !trusted {
            print("[Slab] WARNING: Accessibility permission not granted — mouse events will NOT be delivered.")
        }

        globalMouseDown = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] in
            self?.handleMouseDown($0)
        }
        globalMouseDrag = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] in
            self?.handleMouseDragged($0)
        }
        globalMouseUp = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] in
            self?.handleMouseUp($0)
        }
        localMouseDown = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] e in
            self?.handleMouseDown(e); return e
        }
        localMouseDrag = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] e in
            self?.handleMouseDragged(e); return e
        }
        localMouseUp = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] e in
            self?.handleMouseUp(e); return e
        }
    }

    func stop() {
        let monitors: [Any?] = [globalMouseDown, globalMouseDrag, globalMouseUp,
                                localMouseDown,  localMouseDrag,  localMouseUp]
        for m in monitors.compactMap({ $0 }) {
            NSEvent.removeMonitor(m)
        }
        globalMouseDown = nil; globalMouseDrag = nil; globalMouseUp = nil
        localMouseDown  = nil; localMouseDrag  = nil; localMouseUp  = nil
        previewWindow.hide()
        flyoutWindow.hide()
        dragStart = nil
        lastFlyoutEngagedAt = nil
        state = .idle
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard Defaults.snapOnDragEnabled else {
            return
        }
        let qPt = quartzPoint()
        guard let win = titleBarWindow(at: qPt) else {
            state = .idle
            dragStart = nil
            return
        }
        dragStart = qPt
        state = .dragging(window: win)
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard Defaults.snapOnDragEnabled else { return }
        let qPt  = quartzPoint()
        let akPt = NSEvent.mouseLocation

        let window: WindowInfo
        switch state {
        case .idle:
            return
        case .dragging(let w):
            if let start = dragStart {
                let dist = hypot(qPt.x - start.x, qPt.y - start.y)
                if dist < minDragDistance { return }
            }
            window = w
        case .inEdgeZone(let w, _, _):
            window = w
        case .inFlyoutZone(let w, _, _, _):
            window = w
        }

        guard let screen = ScreenManager.screen(containing: qPt) else {
            previewWindow.hide()
            flyoutWindow.hide()
            state = .dragging(window: window)
            return
        }

        let hit = edgeHit(at: qPt, on: screen)
        let overFlyoutStrict = flyoutWindow.containsScreenPoint(akPt)
        let overFlyoutSticky = flyoutWindow.containsScreenPointSticky(akPt)

        // Cursor is "engaged with the flyout system" when it's either inside
        // the flyout's sticky region, on an edge that would (re)open the
        // flyout, or already over a card. Tracking this lets us apply a
        // small close-delay below.
        let engaged = overFlyoutSticky || hit.flyoutAnchor != nil
        if engaged { lastFlyoutEngagedAt = Date() }

        guard hit.zone != .none || overFlyoutStrict || flyoutWindow.isVisible else {
            previewWindow.hide()
            flyoutWindow.hide()
            lastFlyoutEngagedAt = nil
            state = .dragging(window: window)
            return
        }

        // Open / reposition the flyout when the cursor is on a triggering
        // edge. Anchor it flush against that edge — no dead gap between the
        // hot-zone and the chooser, so the user can drag from edge into
        // flyout in one motion.
        if let anchor = hit.flyoutAnchor {
            flyoutWindow.show(on: screen, anchor: anchor, cursor: akPt)
        } else if !overFlyoutSticky, flyoutWindow.isVisible {
            // Cursor wandered off the triggering edge and out of the flyout's
            // sticky region. Apply a small close-delay to absorb jitter — if
            // the cursor returns within `flyoutCloseDelay`, the flyout stays
            // alive. Without this, dragging from the corridor between edge
            // and flyout occasionally dismisses on the first frame off-edge.
            if let last = lastFlyoutEngagedAt,
               Date().timeIntervalSince(last) > flyoutCloseDelay {
                flyoutWindow.hide()
                lastFlyoutEngagedAt = nil
            }
        }

        if let fHit = flyoutWindow.zoneAt(screenPoint: akPt) {
            flyoutWindow.updateHover(screenPoint: akPt)
            let zoneQuartz = fHit.layout.quartzFrame(for: fHit.zone, on: screen)
            previewWindow.show(at: ScreenManager.toAppKit(zoneQuartz), animated: true)
            state = .inFlyoutZone(window: window, hit: fHit, screen: screen, frame: zoneQuartz)
            return
        }
        flyoutWindow.updateHover(screenPoint: akPt)

        if hit.zone != .none, let frame = ScreenManager.frame(for: hit.zone, on: screen) {
            previewWindow.show(at: ScreenManager.toAppKit(frame), animated: true)
            state = .inEdgeZone(window: window, zone: hit.zone, screen: screen)
            return
        }

        previewWindow.hide()
        state = .dragging(window: window)
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard Defaults.snapOnDragEnabled else {
            previewWindow.hide()
            flyoutWindow.hide()
            dragStart = nil
            state = .idle
            return
        }

        let finalState = state
        let qPt = quartzPoint()
        let akPt = NSEvent.mouseLocation

        state = .idle
        dragStart = nil
        previewWindow.hide()

        if let window = draggedWindow(from: finalState),
           let screen = ScreenManager.screen(containing: qPt),
           let hit = flyoutWindow.zoneAt(screenPoint: akPt) {
            flyoutWindow.hide()
            let frame = hit.layout.quartzFrame(for: hit.zone, on: screen)
            windowManager.snap(window, to: frame)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.onDidSnap?(hit.layout, hit.zone, window, screen)
            }
            return
        }

        flyoutWindow.hide()
        switch finalState {
        case .inEdgeZone(let window, let zone, let screen):
            guard let frame = ScreenManager.frame(for: zone, on: screen) else { return }
            windowManager.snap(window, to: frame)
            // Map the edge snap onto an implicit multi-zone layout so Snap
            // Assist can offer to fill the remaining zones — e.g. after a
            // left-half snap, prompt for a right-half candidate.
            if let mapping = zone.implicitLayoutAndZone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                    self?.onDidSnap?(mapping.layout, mapping.zone, window, screen)
                }
            }
        case .inFlyoutZone(let window, let hit, let screen, let frame):
            windowManager.snap(window, to: frame)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                self?.onDidSnap?(hit.layout, hit.zone, window, screen)
            }
        default:
            break
        }
    }

    private func draggedWindow(from state: DragState) -> WindowInfo? {
        switch state {
        case .idle:
            return nil
        case .dragging(let window),
             .inEdgeZone(let window, _, _),
             .inFlyoutZone(let window, _, _, _):
            return window
        }
    }

    /// Result of an edge-hit test. `flyoutAnchor` (when non-nil) tells the
    /// detector both that the chooser should appear AND which screen edge to
    /// anchor it against — corners deliberately don't trigger the chooser
    /// because direct quadrant snaps are the whole point of corner-snap.
    private struct EdgeHit {
        let zone: SnapZone
        let flyoutAnchor: SnapFlyoutWindow.Anchor?
        static let none = EdgeHit(zone: .none, flyoutAnchor: nil)
    }

    private func edgeHit(at pt: CGPoint, on screen: NSScreen) -> EdgeHit {
        let t = max(Defaults.hotZoneThreshold, 20)
        let cornerT = t * 2
        let f = ScreenManager.toQuartz(screen.frame)

        // Corners get priority — generous radius so they're easy to hit.
        // They fire even on edges shared with another monitor, because
        // quadrant snaps are useful on every screen.
        if pt.x <= f.minX + cornerT && pt.y <= f.minY + cornerT { return EdgeHit(zone: .topLeft,     flyoutAnchor: nil) }
        if pt.x >= f.maxX - cornerT && pt.y <= f.minY + cornerT { return EdgeHit(zone: .topRight,    flyoutAnchor: nil) }
        if pt.x <= f.minX + cornerT && pt.y >= f.maxY - cornerT { return EdgeHit(zone: .bottomLeft,  flyoutAnchor: nil) }
        if pt.x >= f.maxX - cornerT && pt.y >= f.maxY - cornerT { return EdgeHit(zone: .bottomRight, flyoutAnchor: nil) }

        // Outer-edge filter: if another display sits beyond this edge, the
        // user is just moving between monitors — don't ambush them with a snap.
        if pt.x <= f.minX + t, !ScreenManager.hasNeighbor(of: screen, on: .left) {
            return EdgeHit(zone: .leftHalf, flyoutAnchor: .left)
        }
        if pt.x >= f.maxX - t, !ScreenManager.hasNeighbor(of: screen, on: .right) {
            return EdgeHit(zone: .rightHalf, flyoutAnchor: .right)
        }
        if pt.y <= f.minY + t, !ScreenManager.hasNeighbor(of: screen, on: .top) {
            // Landscape: maximize. Portrait: top-half (more useful on a tall
            // monitor than a thin full-screen strip). Either way the flyout
            // opens so the user can override with another layout.
            let zone: SnapZone = ScreenManager.isPortrait(screen) ? .topHalf : .full
            return EdgeHit(zone: zone, flyoutAnchor: .top)
        }

        // Bottom edge is intentionally a no-op — too easy to brush past the
        // Dock and trigger an unwanted snap, almost never what the user means.
        return .none
    }

    private func titleBarWindow(at quartzPt: CGPoint) -> WindowInfo? {
        let titleH: CGFloat = 30
        for win in windowManager.enumerateWindows() {
            let f = win.frame
            let titleBar = CGRect(x: f.minX, y: f.minY, width: f.width, height: titleH)
            if titleBar.contains(quartzPt) { return win }
        }
        return nil
    }

    private func quartzPoint() -> CGPoint {
        let loc = NSEvent.mouseLocation
        let h   = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: loc.x, y: h - loc.y)
    }
}
