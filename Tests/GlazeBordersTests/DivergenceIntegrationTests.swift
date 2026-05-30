import Testing
import AppKit
@testable import GlazeBordersCore

/// LIVE regression for bug #1: an app with a minimum size that GlazeWM tries to
/// shrink below it overflows its tile, so its real AX frame differs from the
/// frame GlazeWM reports. The border must follow the AX frame. This drives the
/// real GlazeWM + AX on the running machine. See IntegrationEnvironment.
@Suite("Integration: AX vs GlazeWM divergence")
@MainActor
struct DivergenceIntegrationTests {
    init() throws { try IntegrationEnvironment.require() }

    @Test("when a window overflows its tile, decide draws the AX frame not GlazeWM's")
    func bordersDrawAtAXFrame() throws {
        let glaze = GlazeClient().queryWindows()
        let focused = try #require(glaze.first { $0.isBordered && $0.hasFocus },
                                   "no focused bordered window")

        // Read the real frame of the frontmost app (the window we actually border).
        let app = try #require(NSWorkspace.shared.frontmostApplication)
        let watcher = AXWatcher(onChange: {})
        guard let info = watcher.watchFocusedWindow(pid: app.processIdentifier) else {
            // AX could not resolve; nothing to assert this run.
            return
        }

        // Feed the live snapshot through the pure decision and confirm it draws
        // the AX frame's width, regardless of whether GlazeWM's width differs.
        let input = Reconciler.Input(
            windows: glaze,
            front: .init(app: app.localizedName ?? "",
                         frame: info.frame,
                         hasToolbar: info.hasToolbar),
            screenFrame: NSScreen.main?.frame)
        let cmd = try #require(Reconciler.decide(input, config: Config().reconcilerSettings,
                                                 classify: { _ in nil }))

        // The drawn overlay width tracks the AX frame, not GlazeWM's reported width.
        // (offset 0 / width 2 => overlay width == window width.)
        let axWidth = info.frame.width
        let drawnWidth = cmd.placement.windowFrame.width
        #expect(abs(drawnWidth - axWidth) <= 1,
                "drawn width \(drawnWidth) should match AX width \(axWidth); GlazeWM reported \(focused.width)")
    }
}
