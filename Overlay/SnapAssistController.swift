import Cocoa
import SwiftUI

final class SnapAssistController {

    private let windowManager: WindowManager
    private var pickers: [SnapAssistPickerWindow] = []
    private var escMonitorGlobal: Any?
    private var escMonitorLocal: Any?
    private var clickMonitorGlobal: Any?
    private var clickMonitorLocal: Any?

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    func begin(layout: AnyLayoutTemplate,
               filledZone: LayoutZone,
               filledWindow: WindowInfo,
               screen: NSScreen) {

        dismiss()

        let remaining = layout.zones.filter { $0.id != filledZone.id }
        guard !remaining.isEmpty else { return }

        let allWindows = windowManager.enumerateWindows()
        var occupiedIDs: Set<CGWindowID> = [filledWindow.id]

        for zone in remaining {
            let candidates = allWindows.filter { !occupiedIDs.contains($0.id) }
            guard !candidates.isEmpty else { continue }

            let picker = SnapAssistPickerWindow(
                layout: layout,
                zone: zone,
                screen: screen,
                candidates: candidates
            )
            picker.onPick = { [weak self, weak picker] chosen in
                guard let self = self, let picker = picker else { return }
                let frame = layout.quartzFrame(for: zone, on: screen)
                self.windowManager.snap(chosen, to: frame)
                occupiedIDs.insert(chosen.id)
                self.remove(picker)
            }
            picker.onSkip = { [weak self, weak picker] in
                guard let self = self, let picker = picker else { return }
                self.remove(picker)
            }
            picker.present()
            pickers.append(picker)
        }

        if !pickers.isEmpty {
            installDismissMonitors()
        }
    }

    func dismiss() {
        for p in pickers { p.dismiss() }
        pickers.removeAll()
        removeDismissMonitors()
    }

    private func remove(_ picker: SnapAssistPickerWindow) {
        picker.dismiss()
        pickers.removeAll { $0 === picker }
        if pickers.isEmpty { removeDismissMonitors() }
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        escMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 {
                DispatchQueue.main.async { self?.dismiss() }
                return nil
            }
            return e
        }
        escMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] e in
            if e.keyCode == 53 {
                DispatchQueue.main.async { self?.dismiss() }
            }
        }

        clickMonitorGlobal = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async { self?.dismissIfClickOutside() }
        }
        clickMonitorLocal = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] e in
            DispatchQueue.main.async { self?.dismissIfClickOutside() }
            return e
        }
    }

    private func removeDismissMonitors() {
        for m in [escMonitorLocal, escMonitorGlobal, clickMonitorGlobal, clickMonitorLocal].compactMap({ $0 }) {
            NSEvent.removeMonitor(m)
        }
        escMonitorLocal = nil
        escMonitorGlobal = nil
        clickMonitorGlobal = nil
        clickMonitorLocal = nil
    }

    private func dismissIfClickOutside() {
        let mouse = NSEvent.mouseLocation
        for p in pickers where p.frame.contains(mouse) { return }
        dismiss()
    }
}

final class SnapAssistPickerWindow: NSPanel {

    let zoneID: String
    private let layout: AnyLayoutTemplate
    private let zone: LayoutZone
    private let screenRef: NSScreen
    private let candidates: [WindowInfo]

    var onPick: ((WindowInfo) -> Void)?
    var onSkip: (() -> Void)?

    init(layout: AnyLayoutTemplate,
         zone: LayoutZone,
         screen: NSScreen,
         candidates: [WindowInfo]) {

        self.zoneID     = zone.id
        self.layout     = layout
        self.zone       = zone
        self.screenRef  = screen
        self.candidates = candidates

        let v = screen.visibleFrame
        let zoneRect = NSRect(
            x: v.minX + zone.unitRect.minX * v.width,
            y: v.minY + zone.unitRect.minY * v.height,
            width:  zone.unitRect.width  * v.width,
            height: zone.unitRect.height * v.height
        )

        let margin: CGFloat = 20
        let maxW: CGFloat   = 360
        let maxH: CGFloat   = 440
        let minW: CGFloat   = 240
        let minH: CGFloat   = 220
        let w = min(max(zoneRect.width  - margin * 2, minW), maxW)
        let h = min(max(zoneRect.height - margin * 2, minH), maxH)
        let rect = NSRect(
            x: zoneRect.midX - w / 2,
            y: zoneRect.midY - h / 2,
            width: w, height: h
        )

        super.init(
            contentRect: rect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]

        let root = SnapAssistPickerView(
            zoneLabel: zone.label,
            candidates: candidates,
            onPick: { [weak self] win in self?.onPick?(win) },
            onSkip: { [weak self] in self?.onSkip?() }
        )
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: rect.size)
        contentView = hosting
    }

    func present() {
        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.14
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animator().alphaValue = 1
        }
    }

    func dismiss() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.orderOut(nil)
        })
    }

    override var canBecomeKey: Bool { true }
}

private struct SnapAssistPickerView: View {
    let zoneLabel: String
    let candidates: [WindowInfo]
    let onPick: (WindowInfo) -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.inset.filled")
                    .foregroundColor(.accentColor)
                Text("Pick a window for ")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)
                + Text(zoneLabel)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onSkip) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .help("Skip this zone")
            }
            .padding(12)

            Divider()

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 1) {
                    ForEach(candidates) { win in
                        WindowCandidateRow(window: win) { onPick(win) }
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 6)
            }

            Divider()

            HStack {
                Text("Esc to dismiss")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Skip", action: onSkip)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding(10)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct WindowCandidateRow: View {
    let window: WindowInfo
    let onSelect: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                if let icon = window.appIcon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "app.dashed")
                        .frame(width: 22, height: 22)
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(window.appName)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if !window.windowTitle.isEmpty && window.windowTitle != window.appName {
                        Text(window.windowTitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Color.accentColor.opacity(0.15) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
