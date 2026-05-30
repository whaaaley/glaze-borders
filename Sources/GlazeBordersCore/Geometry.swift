import CoreGraphics

/// Pure border geometry math — no AppKit, no side effects, fully unit-testable.
///
/// The two tricky parts of drawing a border live here so they can be tested in
/// isolation: (1) the GlazeWM/AX top-left,y-down → AppKit bottom-left,y-up
/// coordinate flip, and (2) where to place the overlay window and the stroke
/// path so the stroke's OUTER edge lands at the requested offset from the
/// window edge. Getting these wrong was the entire class of "border is offset"
/// bugs we hit, so they get their own tested module.
public enum Geometry {
    /// The computed placement for one border overlay.
    public struct Placement: Equatable {
        /// The overlay window's frame in AppKit (bottom-left origin) coordinates.
        public let windowFrame: CGRect
        /// The stroke path rect, in the overlay's local coordinates.
        public let pathRect: CGRect
    }

    /// Compute the overlay placement for a window.
    ///
    /// - Parameters:
    ///   - windowFrame: the target window's frame in GlazeWM/AX coords
    ///     (top-left origin, y-down).
    ///   - screenFrame: the frame of the screen the window lives on, in AppKit
    ///     coords (used for the y-flip and multi-screen origin offset).
    ///   - width: border stroke width in points.
    ///   - offset: how far the border sits from the window edge. 0 = pure inner
    ///     (stroke fully inside the edge); negative pushes the stroke outward by
    ///     |offset| points.
    public static func placement(windowFrame glaze: CGRect,
                                 screenFrame: CGRect,
                                 width: CGFloat,
                                 offset: CGFloat) -> Placement {
        // Flip y: GlazeWM measures y from the top of the screen down; AppKit
        // window origins are from the bottom up.
        let flippedY = screenFrame.height - (glaze.origin.y + glaze.height)

        let half = width / 2
        let outward = -offset           // positive => stroke pushed outside the edge
        let grow = max(outward, 0)      // overlay must contain the whole stroke

        let windowFrame = CGRect(
            x: glaze.origin.x - grow,
            y: flippedY - grow,
            width: glaze.width + grow * 2,
            height: glaze.height + grow * 2
        ).offsetBy(dx: screenFrame.origin.x, dy: screenFrame.origin.y)

        // Stroke is centered on its path, so the path sits `half` inside the
        // desired outer edge. The outer edge is `grow - outward` from the overlay
        // edge (that distance equals the window edge), so pathInset = that + half.
        let pathInset = (grow - outward) + half
        let pathRect = CGRect(origin: .zero, size: windowFrame.size)
            .insetBy(dx: pathInset, dy: pathInset)

        return Placement(windowFrame: windowFrame, pathRect: pathRect)
    }
}
