import Testing
@testable import GlazeBordersCore

/// LIVE integration: drives the real `glazewm` CLI on this machine. Requires
/// GlazeWM to be running (checked in init, which swift-testing runs before each
/// test). See IntegrationEnvironment for the prerequisite gate.
@Suite("Integration: GlazeClient")
struct GlazeClientIntegrationTests {
    init() throws { try IntegrationEnvironment.require() }

    @Test("query windows returns well-formed live data")
    func queryWindowsLive() {
        let windows = GlazeClient().queryWindows()
        // GlazeWM is running (init guaranteed it), so there is at least one window.
        #expect(!windows.isEmpty)
        // Every window has a non-empty id and process name.
        for w in windows {
            #expect(!w.id.isEmpty)
            #expect(!w.processName.isEmpty)
        }
    }

    @Test("exactly one window reports focus")
    func oneFocusedWindow() {
        let focused = GlazeClient().queryWindows().filter(\.hasFocus)
        #expect(focused.count <= 1)
    }
}
