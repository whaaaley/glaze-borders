import AppKit

/// A single transparent, click-through window that draws one rounded border.
/// One Overlay is reused per GlazeWM window id and just repositioned/recolored.
///
/// Why this avoids the JankyBorders hidpi-offset bug: we work entirely in
/// AppKit POINTS and let the window server handle Retina scaling. We never do
/// manual `* backingScaleFactor` math on the frame, which is exactly where the
/// offset crept in. The only conversion is GlazeWM's top-left/y-down origin to
/// AppKit's bottom-left/y-up, done once, correctly, in `update`.
@MainActor
final class Overlay {
    private let window: NSWindow
    private let shape = CAShapeLayer()

    let width: CGFloat   // stroke line width (placement math is done elsewhere)

    init(width: CGFloat) {
        self.width = width

        window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true              // click-through
        window.level = .init(Int(CGWindowLevelForKey(.floatingWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]

        let host = NSView()
        host.wantsLayer = true
        host.layer?.addSublayer(shape)
        shape.fillColor = NSColor.clear.cgColor
        // Disable Core Animation's implicit animations: color/path/frame changes
        // must apply INSTANTLY (no fade/tween) so borders feel snappy when focus
        // swaps or windows move. nil actions = no implicit animation for any key.
        shape.actions = [
            "strokeColor": NSNull(), "path": NSNull(),
            "lineWidth": NSNull(), "frame": NSNull(),
            "bounds": NSNull(), "position": NSNull(),
        ]
        window.contentView = host
    }

    /// Apply a precomputed placement (the geometry math is done by the pure
    /// Reconciler/Geometry); this just pushes it to AppKit. No implicit
    /// animations — changes apply instantly so the border stays snappy.
    func apply(placement p: Geometry.Placement, color: NSColor, cornerRadius: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        window.setFrame(p.windowFrame, display: true)

        shape.path = CGPath(roundedRect: p.pathRect,
                            cornerWidth: cornerRadius,
                            cornerHeight: cornerRadius,
                            transform: nil)
        shape.lineWidth = width
        shape.strokeColor = color.cgColor
        shape.frame = CGRect(origin: .zero, size: p.windowFrame.size)

        if !window.isVisible { window.orderFront(nil) }
    }

    func hide() { window.orderOut(nil) }
}
