import Cocoa

/// A single window that was part of a snap group, captured at snap time.
///
/// Identity uses (`appBundleID`, `windowTitle`) rather than `CGWindowID` so
/// the entry survives the user switching apps, hiding/unhiding, or even a
/// window being briefly closed and reopened — the assumption being that a
/// "group" is conceptually about the apps the user arranged, not the specific
/// CG window handles at snap time.
struct SnapGroupEntry {
    let appBundleID: String?
    let appName: String
    let windowTitle: String
    let quartzFrame: CGRect
    let timestamp: Date
}

/// A set of windows the user snapped in quick succession.
///
/// "Quick succession" matters because it disambiguates intent: if you snap
/// Mail to the left and then Safari to the right within a few seconds, those
/// are the pair you want restored together. If you snap Mail and then ten
/// minutes later snap Slack to the right, that's a different group.
struct SnapGroup {
    let entries: [SnapGroupEntry]
    let createdAt: Date
}

/// In-memory tracker for the user's most-recent snap group, intended to be
/// driven by `WindowManager.snap`. Not persisted across launches in v0; the
/// goal is to power a "Restore Last Snap Group" action within a session.
final class SnapGroupStore {

    /// How long after the last snap before we consider the active group
    /// "complete" and stop accreting new entries into it.
    private let groupingWindow: TimeInterval = 8.0

    /// The group still accreting entries — promoted to `lastGroup` after the
    /// grouping window elapses or when the user explicitly requests restore.
    private var pending: [SnapGroupEntry] = []
    private var lastSnapAt: Date?

    /// The most recently completed group, available for restore.
    private(set) var lastGroup: SnapGroup?

    /// Record a snap. If it lands within `groupingWindow` of the previous
    /// snap, it joins the pending group; otherwise it starts a new one.
    func record(window: WindowInfo, quartzFrame: CGRect) {
        let now = Date()
        if let last = lastSnapAt, now.timeIntervalSince(last) > groupingWindow {
            // Promote the previous pending set, then start fresh.
            promote()
        }
        let entry = SnapGroupEntry(
            appBundleID: window.appBundleID,
            appName: window.appName,
            windowTitle: window.windowTitle,
            quartzFrame: quartzFrame,
            timestamp: now
        )
        // Replace any prior entry for the same window — re-snapping the same
        // window into a new zone should update its slot, not create a duplicate.
        pending.removeAll { matches($0, window) }
        pending.append(entry)
        lastSnapAt = now
    }

    /// Snapshot whatever's currently pending into `lastGroup` so the user
    /// can ask for it back. Idempotent — calling twice does nothing extra.
    func promote() {
        guard pending.count >= 2 else {
            // A "group" needs at least two windows to be meaningful.
            return
        }
        lastGroup = SnapGroup(entries: pending, createdAt: Date())
        pending.removeAll()
    }

    /// Re-snap each entry's matching live window back to its recorded frame.
    /// Promotes any pending group first so the user gets the latest data.
    func restoreLast(using windowManager: WindowManager) {
        promote()
        guard let group = lastGroup else { return }

        let liveWindows = windowManager.enumerateWindows()
        for entry in group.entries {
            // Try exact (bundle, title) — strongest match.
            // Fall back to (bundle, any window of that app) — covers the case
            // where the title changed since the snap (e.g. browser tab swap).
            let match = liveWindows.first { w in
                guard let bid = entry.appBundleID, w.appBundleID == bid else { return false }
                return w.windowTitle == entry.windowTitle
            } ?? liveWindows.first { w in
                entry.appBundleID != nil && w.appBundleID == entry.appBundleID
            }
            guard let target = match else { continue }
            windowManager.snap(target, to: entry.quartzFrame)
        }
    }

    /// True when there's a group available for `restoreLast` (either fully
    /// promoted or about-to-be-promoted from pending entries).
    var hasRestorableGroup: Bool {
        lastGroup != nil || pending.count >= 2
    }

    private func matches(_ entry: SnapGroupEntry, _ window: WindowInfo) -> Bool {
        entry.appBundleID == window.appBundleID && entry.windowTitle == window.windowTitle
    }
}
