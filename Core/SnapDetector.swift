import Cocoa

final class SnapDetector {

    private enum DragState {
        case idle
        case dragging(window: WindowInfo, startQuartz: CGPoint)
        case inHotZone(window: WindowInfo, zone: SnapZone, screen: NSScreen)
    }

    private let windowManager: WindowManager
    private let previewWindow = SnapPreviewWindow()

    private var state: DragState = .idle
    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor:   Any?

    /// Must move at least this many points before snap detection activates.
    /// Prevents accidental snaps from simple title-bar clicks.
    private let minDragDistance: CGFloat = 10

    var onRequestLayoutPicker: (() -> Void)?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    // MARK: - Lifecycle

    func start() {
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] in
            self?.onMouseDown($0)
        }
        mouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] in
            self?.onMouseDragged($0)
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] in
            self?.onMouseUp($0)
        }
    }

    func stop() {
        for m in [mouseDownMonitor, mouseDragMonitor, mouseUpMonitor].compactMap({ $0 }) {
            NSEvent.removeMonitor(m)
        }
        mouseDownMonitor = nil
        mouseDragMonitor = nil
        mouseUpMonitor   = nil
        previewWindow.hide()
        state = .idle
    }

    // MARK: - Event Handlers

    private func onMouseDown(_ event: NSEvent) {
        guard Defaults.snapOnDragEnabled else { return }
        let pt = quartzPoint()
        guard let win = titleBarWindow(at: pt) else { state = .idle; return }
        state = .dragging(window: win, startQuartz: pt)
    }

    private func onMouseDragged(_ event: NSEvent) {
        guard Defaults.snapOnDragEnabled else { return }
        let pt = quartzPoint()

        switch state {
        case .idle:
            break

        case .dragging(let window, let startPt):
            // Don't trigger until cursor has moved enough (avoids title-bar click noise)
            let dist = hypot(pt.x - startPt.x, pt.y - startPt.y)
            guard dist >= minDragDistance else { return }

            guard let screen = ScreenManager.screen(containing: pt) else { return }
            let zone = hotZone(at: pt, on: screen)

            if zone != .none {
                if let frame = ScreenManager.frame(for: zone, on: screen) {
                    previewWindow.show(at: ScreenManager.toAppKit(frame))
                }
                state = .inHotZone(window: window, zone: zone, screen: screen)
            }
            // (no else — just keep dragging silently)

        case .inHotZone(let window, _, _):
            guard let screen = ScreenManager.screen(containing: pt) else { return }
            let zone = hotZone(at: pt, on: screen)

            if zone == .none {
                // Cursor moved back out — cancel preview, return to dragging
                previewWindow.hide()
                state = .dragging(window: window, startQuartz: pt)
            } else {
                // Zone changed (e.g., corner → edge) — update preview
                if let frame = ScreenManager.frame(for: zone, on: screen) {
                    previewWindow.show(at: ScreenManager.toAppKit(frame), animated: true)
                }
                state = .inHotZone(window: window, zone: zone, screen: screen)
            }
        }
    }

    private func onMouseUp(_ event: NSEvent) {
        defer { state = .idle }
        guard case .inHotZone(let window, let zone, let screen) = state else { return }
        previewWindow.hide()
        if let frame = ScreenManager.frame(for: zone, on: screen) {
            windowManager.snap(window, to: frame)
        }
    }

    // MARK: - Hot Zone Detection

    /// Returns the snap zone for the cursor, or .none.
    /// Uses a larger threshold (40 px) to feel like Windows 11.
    private func hotZone(at pt: CGPoint, on screen: NSScreen) -> SnapZone {
        let t = max(Defaults.hotZoneThreshold, 20)   // at least 20 px — matches Windows feel
        let cornerT = t * 2                           // corners need less precision
        let f = ScreenManager.toQuartz(screen.frame)  // full screen frame in Quartz coords

        // Top-center → open layout picker (Windows 11 "snap flyout" zone)
        let topCenterZone = CGRect(
            x: f.midX - 120, y: f.minY,
            width: 240, height: t
        )
        if topCenterZone.contains(pt) {
            DispatchQueue.main.async { [weak self] in self?.onRequestLayoutPicker?() }
            return .none   // don't snap the window itself
        }

        // Corners (priority)
        if pt.x <= f.minX + cornerT && pt.y <= f.minY + cornerT { return .topLeft }
        if pt.x >= f.maxX - cornerT && pt.y <= f.minY + cornerT { return .topRight }
        if pt.x <= f.minX + cornerT && pt.y >= f.maxY - cornerT { return .bottomLeft }
        if pt.x >= f.maxX - cornerT && pt.y >= f.maxY - cornerT { return .bottomRight }

        // Edges
        if pt.x <= f.minX + t { return .leftHalf }
        if pt.x >= f.maxX - t { return .rightHalf }
        if pt.y <= f.minY + t { return .topHalf }
        if pt.y >= f.maxY - t { return .bottomHalf }

        return .none
    }

    // MARK: - Window Detection

    /// Returns the window whose title bar the click landed in.
    private func titleBarWindow(at quartzPt: CGPoint) -> WindowInfo? {
        let wins = windowManager.enumerateWindows()
        let titleH: CGFloat = 30   // standard macOS title bar height

        // Check in Z-order (enumerateWindows returns front-to-back)
        for win in wins {
            let f = win.frame  // Quartz: origin = top-left, Y increases downward
            // Title bar = top 'titleH' pixels of the window in Quartz space
            let titleBar = CGRect(x: f.minX, y: f.minY, width: f.width, height: titleH)
            if titleBar.contains(quartzPt) { return win }
        }
        return nil
    }

    // MARK: - Helpers

    private func quartzPoint() -> CGPoint {
        let loc = NSEvent.mouseLocation          // AppKit: bottom-left origin
        let h   = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: loc.x, y: h - loc.y)  // flip to Quartz
    }
}
