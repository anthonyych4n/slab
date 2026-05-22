import Cocoa
import ApplicationServices

final class WindowManager {

    private let history = WindowHistory()
    let groupStore = SnapGroupStore()

    // MARK: - Enumeration

    /// Returns all visible, normal-layer windows across all apps.
    func enumerateWindows() -> [WindowInfo] {
        let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]]
        else { return [] }

        return list.compactMap { dict -> WindowInfo? in
            guard
                let windowID  = dict[kCGWindowNumber as String] as? CGWindowID,
                let pid       = dict[kCGWindowOwnerPID as String] as? Int32,
                let layer     = dict[kCGWindowLayer as String] as? Int,
                layer == 0,
                let boundsRaw = dict[kCGWindowBounds as String]
            else { return nil }

            let bounds = CGRect(dictionaryRepresentation: boundsRaw as! CFDictionary)!
            guard bounds.width > 100, bounds.height > 100 else { return nil }

            let appName = dict[kCGWindowOwnerName as String] as? String ?? ""
            let title   = dict[kCGWindowName as String] as? String ?? ""

            // Skip Slab's own windows
            if appName == "Slab" { return nil }

            let app = NSRunningApplication(processIdentifier: pid)
            return WindowInfo(
                id: windowID,
                pid: pid,
                appName: appName,
                windowTitle: title,
                appBundleID: app?.bundleIdentifier,
                appIcon: app?.icon,
                frame: bounds  // Quartz coords
            )
        }
    }

    // MARK: - Snapping

    /// Snap the frontmost window to a snap zone using a cycling strategy.
    func snapFrontmost(to zone: SnapZone) {
        guard let win = frontmostWindow() else { return }
        let screen = ScreenManager.bestScreen(for: win.frame)
        guard let targetFrame = ScreenManager.frame(for: zone, on: screen) else { return }
        history.record(windowID: win.id, frame: win.frame)
        snap(win, to: targetFrame)
    }

    /// Snap any WindowInfo to an explicit Quartz frame.
    func snap(_ window: WindowInfo, to quartzFrame: CGRect) {
        guard let axWin = resolveAXWindow(for: window) else { return }
        history.record(windowID: window.id, frame: window.frame)
        setFrame(axWin, to: quartzFrame)
        // Feed the group tracker after the snap actually lands — this is the
        // single chokepoint every snap (drag, hotkey, picker, assist) flows
        // through, so we only need to track here.
        groupStore.record(window: window, quartzFrame: quartzFrame)
    }

    /// Restore the frontmost window to its pre-snap frame.
    func unsnapFrontmost() {
        guard let win = frontmostWindow(),
              let original = history.original(for: win.id)
        else { return }
        guard let axWin = resolveAXWindow(for: win) else { return }
        setFrame(axWin, to: original)
        history.clear(windowID: win.id)
    }

    func unsnap(_ window: WindowInfo) {
        guard let original = history.original(for: window.id),
              let axWin = resolveAXWindow(for: window)
        else { return }
        setFrame(axWin, to: original)
        history.clear(windowID: window.id)
    }

    // MARK: - AX Helpers

    private func setFrame(_ axWin: AXUIElement, to frame: CGRect) {
        var size = frame.size
        var origin = frame.origin

        // Set size → position → size again.
        // The second size call handles apps that clamp size based on the current screen position.
        if let sv = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWin, kAXSizeAttribute as CFString, sv)
        }
        if let pv = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(axWin, kAXPositionAttribute as CFString, pv)
        }
        if let sv = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(axWin, kAXSizeAttribute as CFString, sv)
        }
    }

    private func resolveAXWindow(for window: WindowInfo) -> AXUIElement? {
        let axApp = AXUIElementCreateApplication(window.pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement]
        else { return nil }

        // Match by title first
        for axWin in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWin, kAXTitleAttribute as CFString, &titleRef)
            if let title = titleRef as? String, title == window.windowTitle, !title.isEmpty {
                return axWin
            }
        }

        // Frame-based fallback: find the AX window whose position is closest to the known frame
        let knownOrigin = window.frame.origin
        var best: AXUIElement? = windows.first
        var bestDist = CGFloat.greatestFiniteMagnitude
        for axWin in windows {
            var posRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posRef) == .success,
                  let posVal = posRef
            else { continue }
            var pos = CGPoint.zero
            AXValueGetValue(posVal as! AXValue, .cgPoint, &pos)
            let dist = hypot(pos.x - knownOrigin.x, pos.y - knownOrigin.y)
            if dist < bestDist { bestDist = dist; best = axWin }
        }
        return best
    }

    private func frontmostWindow() -> WindowInfo? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)
        var winRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &winRef) == .success,
              let axWin = winRef
        else {
            // Fallback: use enumeration and pick the first window from this PID
            return enumerateWindows().first { $0.pid == pid }
        }

        // Get frame of the focused AX window to build a WindowInfo
        var posRef: CFTypeRef?, sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWin as! AXUIElement, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(axWin as! AXUIElement, kAXSizeAttribute as CFString, &sizeRef)
        var pos = CGPoint.zero; var size = CGSize.zero
        if let pv = posRef  { AXValueGetValue(pv as! AXValue, .cgPoint, &pos) }
        if let sv = sizeRef { AXValueGetValue(sv as! AXValue, .cgSize,  &size) }

        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWin as! AXUIElement, kAXTitleAttribute as CFString, &titleRef)
        let title = titleRef as? String ?? ""

        return WindowInfo(
            id: 0,  // ID not needed for immediate snap
            pid: pid,
            appName: app.localizedName ?? "",
            windowTitle: title,
            appBundleID: app.bundleIdentifier,
            appIcon: app.icon,
            frame: CGRect(origin: pos, size: size)
        )
    }
}
