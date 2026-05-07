import Cocoa

final class SnapPreviewWindow: NSWindow {

    private let contentContainer = PreviewContentView()

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

        contentView = contentContainer
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
            // Start slightly inset and fade/scale in for a snappy entrance.
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

/// A frosted, rounded preview surface with an accent-tinted overlay and border.
private final class PreviewContentView: NSView {

    private let blur: NSVisualEffectView = {
        let v = NSVisualEffectView()
        v.material = .hudWindow
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

    override var isFlipped: Bool { false }

    private func setup() {
        wantsLayer = true
        layer?.masksToBounds = false

        // Soft drop shadow on the host layer (outside the blur's clipped layer).
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        self.shadow = shadow

        addSubview(blur)
        blur.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: trailingAnchor),
            blur.topAnchor.constraint(equalTo: topAnchor),
            blur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        // Accent tint sits on top of the blur, inside the same rounded clip.
        tintLayer.cornerRadius = 14
        tintLayer.cornerCurve = .continuous
        tintLayer.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.22).cgColor
        blur.layer?.addSublayer(tintLayer)

        // Crisp 1.5pt accent border on top.
        borderLayer.cornerRadius = 14
        borderLayer.cornerCurve = .continuous
        borderLayer.borderWidth = 1.5
        borderLayer.borderColor = NSColor.controlAccentColor
            .withAlphaComponent(0.95).cgColor
        borderLayer.backgroundColor = NSColor.clear.cgColor
        blur.layer?.addSublayer(borderLayer)
    }

    override func layout() {
        super.layout()
        // Disable implicit animation when frame changes (parent window animates already).
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tintLayer.frame = blur.bounds
        borderLayer.frame = blur.bounds
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        tintLayer.backgroundColor = NSColor.controlAccentColor
            .withAlphaComponent(0.22).cgColor
        borderLayer.borderColor = NSColor.controlAccentColor
            .withAlphaComponent(0.95).cgColor
    }
}
