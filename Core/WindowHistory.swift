import CoreGraphics

/// Stores pre-snap frames so windows can be restored after unsnapping.
final class WindowHistory {
    private var history: [CGWindowID: CGRect] = [:]

    /// Record the original frame. Only saves the FIRST call per window ID.
    func record(windowID: CGWindowID, frame: CGRect) {
        if history[windowID] == nil {
            history[windowID] = frame
        }
    }

    func original(for windowID: CGWindowID) -> CGRect? {
        return history[windowID]
    }

    func clear(windowID: CGWindowID) {
        history.removeValue(forKey: windowID)
    }

    /// Remove stale entries for windows that no longer exist.
    func pruneStale(against liveIDs: Set<CGWindowID>) {
        history = history.filter { liveIDs.contains($0.key) }
    }
}
