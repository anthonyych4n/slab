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

        let edgeZone = hotZone(at: qPt, on: screen)
        let overFlyout = flyoutWindow.containsScreenPoint(akPt)

        guard edgeZone != .none || overFlyout || flyoutWindow.isVisible else {
            previewWindow.hide()
            flyoutWindow.hide()
            state = .dragging(window: window)
            return
        }

        if edgeZone != .none {
            flyoutWindow.show(on: screen, near: akPt)
        }

        if let hit = flyoutWindow.zoneAt(screenPoint: akPt) {
            flyoutWindow.updateHover(screenPoint: akPt)
            let zoneQuartz = hit.layout.quartzFrame(for: hit.zone, on: screen)
            previewWindow.show(at: ScreenManager.toAppKit(zoneQuartz), animated: true)
            state = .inFlyoutZone(window: window, hit: hit, screen: screen, frame: zoneQuartz)
            return
        }
        flyoutWindow.updateHover(screenPoint: akPt)

        if edgeZone != .none, let frame = ScreenManager.frame(for: edgeZone, on: screen) {
            previewWindow.show(at: ScreenManager.toAppKit(frame), animated: true)
            state = .inEdgeZone(window: window, zone: edgeZone, screen: screen)
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

    private func hotZone(at pt: CGPoint, on screen: NSScreen) -> SnapZone {
        let t = max(Defaults.hotZoneThreshold, 20)
        let cornerT = t * 2
        let f = ScreenManager.toQuartz(screen.frame)

        if pt.x <= f.minX + cornerT && pt.y <= f.minY + cornerT { return .topLeft }
        if pt.x >= f.maxX - cornerT && pt.y <= f.minY + cornerT { return .topRight }
        if pt.x <= f.minX + cornerT && pt.y >= f.maxY - cornerT { return .bottomLeft }
        if pt.x >= f.maxX - cornerT && pt.y >= f.maxY - cornerT { return .bottomRight }

        if pt.x <= f.minX + t { return .leftHalf }
        if pt.x >= f.maxX - t { return .rightHalf }
        if pt.y <= f.minY + t { return .topHalf }
        if pt.y >= f.maxY - t { return .bottomHalf }

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
