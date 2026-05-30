import CoreGraphics

/// Pure logic for picking a window's corner radius — no AppKit/AX, testable.
///
/// macOS Tahoe uses different corner radii by window type. We can't read the
/// real value, but we resolve a good match from, in priority order:
///   1. a per-app override (windows that fit no class, e.g. About This Mac)
///   2. the window's class (toolbar windows are rounder than plain ones)
public enum RadiusResolver {
    public struct Config: Equatable {
        public var plain: CGFloat
        public var toolbar: CGFloat
        public var overrides: [String: CGFloat]
        public init(plain: CGFloat, toolbar: CGFloat, overrides: [String: CGFloat]) {
            self.plain = plain
            self.toolbar = toolbar
            self.overrides = overrides
        }
    }

    /// Resolve the radius for `app`, given whether it's a known toolbar window.
    /// - Parameters:
    ///   - app: the application name (used for override lookup).
    ///   - isToolbar: whether the app's window is classified as a toolbar window.
    ///   - config: the radius config (defaults + overrides).
    public static func radius(app: String, isToolbar: Bool, config: Config) -> CGFloat {
        if let override = config.overrides[app] { return override }
        return isToolbar ? config.toolbar : config.plain
    }
}
