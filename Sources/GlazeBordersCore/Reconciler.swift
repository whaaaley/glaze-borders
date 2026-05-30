import CoreGraphics

/// The pure decision core of the daemon: given a snapshot of the world, decide
/// what (if anything) to draw. No AppKit, no AX, no I/O — every input is passed
/// in, so this is fully unit-testable. The imperative shell (Daemon) gathers the
/// inputs via closures and applies the resulting command.
public enum Reconciler {

    /// A snapshot of everything the decision needs, gathered by the shell.
    public struct Input {
        /// All GlazeWM windows (we pick the focused, bordered one).
        public var windows: [GlazeWindow]
        /// The frontmost app's name + real AX window info, if resolvable. This is
        /// the window we actually border (may differ from GlazeWM's focus for
        /// floating windows like About This Mac).
        public var front: Front?
        /// The screen the border lives on (AppKit coords) for the y-flip.
        public var screenFrame: CGRect?

        public struct Front {
            public var app: String
            public var frame: CGRect
            public var hasToolbar: Bool
            public init(app: String, frame: CGRect, hasToolbar: Bool) {
                self.app = app; self.frame = frame; self.hasToolbar = hasToolbar
            }
        }

        public init(windows: [GlazeWindow], front: Front?, screenFrame: CGRect?) {
            self.windows = windows; self.front = front; self.screenFrame = screenFrame
        }
    }

    /// What to draw. `nil` means "hide the border".
    public struct Command: Equatable {
        public let placement: Geometry.Placement
        public let cornerRadius: CGFloat
        /// Identity of the window being bordered (for focus-change detection).
        public let windowId: String
    }

    /// Decide the draw command for an input snapshot.
    ///
    /// - Parameters:
    ///   - input: the gathered world snapshot.
    ///   - config: border config (width/offset/radii/overrides).
    ///   - classify: looks up an app's known class (toolbar/plain) — injected so
    ///     the persistent classifier stays in the shell. Returns nil if unknown.
    /// - Returns: a draw command, or nil to hide the border.
    public static func decide(
        _ input: Input,
        config: Settings,
        classify: (String) -> Classifier.Kind?
    ) -> Command? {
        // Only border the focused, bordered GlazeWM window.
        guard let w = input.windows.first(where: { $0.isBordered && $0.hasFocus }),
              let screenFrame = input.screenFrame
        else { return nil }

        // The bordered window: prefer the frontmost app's real AX frame; fall
        // back to GlazeWM's frame (and processName) if AX didn't resolve.
        let glazeFrame = CGRect(x: w.x, y: w.y, width: w.width, height: w.height)
        let app = input.front?.app ?? w.processName
        let frame = input.front?.frame ?? glazeFrame

        // Toolbar class comes from the injected classifier (the shell records the
        // AX toolbar observation before calling decide), so a transient AX miss
        // doesn't change the radius.
        let radius = RadiusResolver.radius(
            app: app,
            isToolbar: classify(app) == .toolbar,
            config: .init(plain: config.cornerRadius,
                          toolbar: config.cornerRadiusToolbar,
                          overrides: config.radiusOverrides))

        let placement = Geometry.placement(windowFrame: frame,
                                           screenFrame: screenFrame,
                                           width: config.width,
                                           offset: config.offset)
        return Command(placement: placement, cornerRadius: radius, windowId: w.id)
    }

    /// The subset of Config the decision needs (keeps Reconciler free of AppKit).
    public struct Settings: Equatable {
        public var width: CGFloat
        public var offset: CGFloat
        public var cornerRadius: CGFloat
        public var cornerRadiusToolbar: CGFloat
        public var radiusOverrides: [String: CGFloat]
        public init(width: CGFloat, offset: CGFloat, cornerRadius: CGFloat,
                    cornerRadiusToolbar: CGFloat, radiusOverrides: [String: CGFloat]) {
            self.width = width; self.offset = offset
            self.cornerRadius = cornerRadius; self.cornerRadiusToolbar = cornerRadiusToolbar
            self.radiusOverrides = radiusOverrides
        }
    }
}
