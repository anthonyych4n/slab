import Cocoa

final class SnapPreviewWindow: NSWindow {

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        // Explicit floating level — the flyout sits at .screenSaver, far
        // above this, so when both are on screen the chooser always wins.
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        hasShadow = false
        isReleasedWhenClosed = false

        contentView = PreviewContentView()
    }

    /// Show the preview at the given AppKit-coordinate frame.
    func show(at appKitFrame: CGRect, animated: Bool = true) {
        if isVisible && animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                animator().setFrame(appKitFrame, display: true)
            }
        } else {
            // Inset start frame so the preview eases outward into place — feels
            // snappier than a pure fade and reinforces the "landing" metaphor.
            let inset: CGFloat = 12
            let startFrame = appKitFrame.insetBy(dx: inset, dy: inset)
            setFrame(startFrame, display: false)
            alphaValue = 0
            orderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                ctx.allowsImplicitAnimation = true
                animator().alphaValue = 1
                animator().setFrame(appKitFrame, display: true)
            }
        }
    }

    func hide() {
        guard isVisible else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1
        })
    }
}

/// Frosted-glass preview surface: NSVisualEffectView underlay, accent tint,
/// 1.5pt accent border, continuous-corner radius, soft drop shadow.
private final class PreviewContentView: NSView {

    private let blur: NSVisualEffectView = {
        let v = NSVisualEffectView()
        // .popover is lighter than .hudWindow and reads as a native macOS
        // overlay rather than a dark debug surface.
        v.material = .popover
        v.blendingMode = .behindWindow
        v.state = .active
        v.wantsLayer = true
        v.layer?.cornerRadius = 14
        v.layer?.cornerCurve = .continuous
        v.layer?.masksToBounds = true
        return v
    }()

    private let tintLayer = CALayer()
    private let borderLayer = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Drop shadow lives on the host view (outside the blur's clipped layer)
        // so it can extend beyond the rounded corners.
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        self.shadow = shadow

        addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        tintLayer.cornerRadius = 14
        tintLayer.cornerCurve = .continuous
        // Subtle accent wash — outline reads first, fill second.
        tintLayer.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.10).cgColor
        blur.layer?.addSublayer(tintLayer)

        borderLayer.cornerRadius = 14
        borderLayer.cornerCurve = .continuous
        borderLayer.borderWidth = 1.0
        borderLayer.borderColor = NSColor.controlAccentColor
            .withAlphaComponent(0.70).cgColor
        borderLayer.backgroundColor = NSColor.clear.cgColor
        blur.layer?.addSublayer(borderLayer)
    }

    override func layout() {
        super.layout()
        // Avoid implicit animation on these layers — the host window already
        // animates the frame, and double-animation looks rubbery.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintLayer.frame = blur.bounds
        borderLayer.frame = blur.bounds
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // Subtle accent wash — outline reads first, fill second.
        tintLayer.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.10).cgColor
        borderLayer.borderColor = NSColor.controlAccentColor
            .withAlphaComponent(0.95).cgColor
    }
}
