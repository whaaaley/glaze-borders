import CoreGraphics
import Foundation

/// Small parsing helpers shared by the entry point and tests.
///
/// Kept pure (no process side effects) so they can be unit-tested by passing an
/// explicit environment dictionary instead of reading `ProcessInfo`.
public enum EnvParse {
    /// Read `key` from `env` and parse it as a `CGFloat`, or return `nil` when the
    /// key is absent or not a valid number. Collapses the repeated
    /// `if let s = env[k], let v = Double(s) { CGFloat(v) }` dance at the call site.
    public static func cgFloat(_ env: [String: String], _ key: String) -> CGFloat? {
        guard let raw = env[key], let value = Double(raw) else { return nil }
        return CGFloat(value)
    }

    /// True when `key` is present and equal to `"1"` (our convention for boolean
    /// feature flags like `GLAZE_BORDERS_POP`).
    public static func flag(_ env: [String: String], _ key: String) -> Bool {
        env[key] == "1"
    }
}
