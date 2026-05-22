import Cocoa
import SwiftUI

final class LayoutPickerWindow: NSPanel {

    private let windowManager: WindowManager
    private var hostingView: NSHostingView<LayoutPickerRootView>?
    private var clickOutsideMonitor: Any?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .transient]
    }

    // NSPanel + .nonactivatingPanel returns NO from canBecomeKey by default —
    // forcing this on lets the picker receive Esc / arrow keys without
    // stealing focus from the underlying app.
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func show() {
        let windows = windowManager.enumerateWindows()
        let allLayouts = builtInLayouts + Defaults.customLayouts.map { AnyLayoutTemplate($0) }

        let rootView = LayoutPickerRootView(
            layouts: allLayouts,
            availableWindows: windows,
            onApply: { [weak self] assignments in
                self?.apply(assignments)
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 500)
        contentView = hosting
        self.hostingView = hosting

        positionNearFrontWindow()
        makeKeyAndOrderFront(nil)
        installClickOutsideMonitor()
    }

    override func close() {
        removeClickOutsideMonitor()
        super.close()
    }

    private func apply(_ assignments: [(LayoutZone, WindowInfo, NSScreen)]) {
        close()
        for (zone, window, screen) in assignments {
            guard let template = assignments.first(where: { $0.1 == window })?.0 else { continue }
            _ = template  // zone already has unitRect, use it directly
            let frame = ScreenManager.toQuartz(
                CGRect(
                    x: screen.visibleFrame.minX + zone.unitRect.minX * screen.visibleFrame.width,
                    y: screen.visibleFrame.minY + zone.unitRect.minY * screen.visibleFrame.height,
                    width:  zone.unitRect.width  * screen.visibleFrame.width,
                    height: zone.unitRect.height * screen.visibleFrame.height
                )
            )
            windowManager.snap(window, to: frame)
        }
    }

    private func positionNearFrontWindow() {
        let screen: NSScreen
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let frontWin = windowManager.enumerateWindows().first(where: { $0.pid == frontApp.processIdentifier }),
           let s = ScreenManager.bestScreen(for: frontWin.frame) as NSScreen? {
            screen = s
        } else {
            screen = NSScreen.main ?? NSScreen.screens[0]
        }
        let sv = screen.visibleFrame
        let x = sv.midX - frame.width / 2
        let y = sv.maxY - frame.height - 40
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installClickOutsideMonitor() {
        clickOutsideMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self else { return event }
            if !self.frame.contains(NSEvent.mouseLocation) {
                self.close()
            }
            return event
        }
    }

    private func removeClickOutsideMonitor() {
        if let m = clickOutsideMonitor { NSEvent.removeMonitor(m) }
        clickOutsideMonitor = nil
    }
}

// MARK: - Root SwiftUI View

struct LayoutPickerRootView: View {
    let layouts: [AnyLayoutTemplate]
    let availableWindows: [WindowInfo]
    let onApply: ([(LayoutZone, WindowInfo, NSScreen)]) -> Void
    let onCancel: () -> Void

    @State private var selectedLayout: AnyLayoutTemplate?
    @State private var pendingAssignments: [(zone: LayoutZone, window: WindowInfo)] = []

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "rectangle.split.3x1.fill")
                    .foregroundColor(.accentColor)
                Text("Layout Picker")
                    .font(.headline)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            if let layout = selectedLayout {
                // App picker phase
                AppPickerView(
                    layout: layout,
                    availableWindows: availableWindows,
                    onAssign: { zone, win in
                        pendingAssignments.removeAll { $0.zone.id == zone.id }
                        pendingAssignments.append((zone, win))
                    },
                    onApply: {
                        let screen = NSScreen.main ?? NSScreen.screens[0]
                        let result = pendingAssignments.map { ($0.zone, $0.window, screen) }
                        onApply(result)
                    },
                    onCancel: {
                        selectedLayout = nil
                        pendingAssignments = []
                    }
                )
            } else {
                // Layout grid phase
                Text("Choose a layout")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(layouts) { layout in
                            LayoutCardView(layout: layout)
                                .onTapGesture {
                                    // Single-zone layouts (e.g. full screen) skip the
                                    // app-picker step and apply to the front window.
                                    if layout.zones.count == 1,
                                       let frontWin = availableWindows.first {
                                        let screen = NSScreen.main ?? NSScreen.screens[0]
                                        let zone = layout.zones[0]
                                        onApply([(zone, frontWin, screen)])
                                    } else {
                                        selectedLayout = layout
                                    }
                                }
                        }
                    }
                    .padding(16)
                }

                Button("Cancel", action: onCancel)
                    .padding(.bottom, 16)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 20)
    }
}

private struct LayoutCardView: View {
    let layout: AnyLayoutTemplate
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            // Use absolute .position(x:y:) inside a clipped GeometryReader so
            // each zone is anchored to the card's own coordinate space. The
            // previous offset-from-center math was correct but fragile and
            // visually overflowed the card background; .position is dead
            // simple and clipping protects against any future drift.
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    Color.clear
                    ForEach(layout.zones) { zone in
                        let w = zone.unitRect.width  * geo.size.width
                        let h = zone.unitRect.height * geo.size.height
                        // unitRect uses Y-up (0 = bottom). Flip into SwiftUI's
                        // Y-down coordinate space for the card.
                        let x = zone.unitRect.minX * geo.size.width
                        let y = geo.size.height - (zone.unitRect.minY + zone.unitRect.height) * geo.size.height
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(isHovered ? 0.32 : 0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color.accentColor.opacity(0.65), lineWidth: 1)
                            )
                            .frame(width: max(0, w - 3), height: max(0, h - 3))
                            .position(x: x + w / 2, y: y + h / 2)
                    }
                }
            }
            .frame(height: 60)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(layout.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(8)
        .background(isHovered ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
    }
}
