import Foundation
import ApplicationServices
import Testing
@testable import GlazeBordersCore

/// Prerequisites for the LIVE integration suites. These tests drive the real
/// GlazeWM IPC and the real Accessibility API, so they cannot run unless both
/// are available on the machine running the tests.
///
/// Rather than skip quietly (which reads as "passed" and hides that the suite
/// never ran), each integration suite calls `IntegrationEnvironment.require()`
/// in its `init()` — swift-testing runs `init()` before every test in the
/// suite, so an unmet prerequisite fails fast with an actionable message naming
/// exactly what to enable.
enum IntegrationEnvironment {
    /// Is GlazeWM running and answering IPC?
    static var glazeWMRunning: Bool {
        !GlazeClient().queryWindows().isEmpty
    }

    /// Has the test process been granted Accessibility permission?
    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// A human-readable list of unmet prerequisites, empty if all satisfied.
    static var unmet: [String] {
        var problems: [String] = []
        if !glazeWMRunning {
            problems.append("GlazeWM is not running (start it so `glazewm query windows` works)")
        }
        if !accessibilityGranted {
            problems.append("Accessibility permission is not granted to the test runner "
                + "(System Settings > Privacy & Security > Accessibility)")
        }
        return problems
    }

    /// Fail the current test with a clear, actionable message if the live
    /// environment is not satisfied. Call from each integration suite's `init()`.
    static func require() throws {
        let problems = unmet
        guard problems.isEmpty else {
            let detail = problems.map { "  - \($0)" }.joined(separator: "\n")
            Issue.record(
                """
                Integration tests cannot run until the live environment is ready:
                \(detail)
                Enable both, then re-run `make test`.
                """)
            throw EnvironmentNotReady()
        }
    }

    struct EnvironmentNotReady: Error {}
}
