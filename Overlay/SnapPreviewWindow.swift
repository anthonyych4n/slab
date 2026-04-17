import Cocoa

final class SnapPreviewWindow: NSWindow {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = false
        isReleasedWhenClosed = false

        let preview = PreviewContentView()
        preview.wantsLayer = true
        contentView = preview
    }

    /// Show the preview at the given AppKit-coordinate frame.
    func show(at appKitFrame: CGRect, animated: Bool = true) {
        if isVisible && animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.12
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                animator().setFrame(appKitFrame, display: true)
            }
        } else {
            setFrame(appKitFrame, display: false)
            alphaValue = 0
            orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.1
                animator().alphaValue = 1
            }
        }
    }

    func hide() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }
}

private final class PreviewContentView: NSView {

    override func draw(_ dirtyRect: NSRect) {
        let accent = NSColor.controlAccentColor

        // Fill
        accent.withAlphaComponent(0.18).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        path.fill()

        // Border
        accent.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}
