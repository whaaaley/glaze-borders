import Testing
import Foundation
@testable import GlazeBordersCore

/// Guards the startup query behavior: before the first GlazeWM event lands, the
/// daemon seeds its focused-window cache from a single `query windows`, and then
/// never re-queries (subsequent reconciles use the cached/event-supplied window).
/// This locks in the perf fix so a refactor can't regress to per-reconcile queries.
@Suite("Startup")
@MainActor
struct StartupTests {

    /// A WindowSource that counts queryWindows() calls and never streams events.
    final class CountingSource: WindowSource, @unchecked Sendable {
        private(set) var queryCount = 0
        let windows: [GlazeWindow]
        init(windows: [GlazeWindow]) { self.windows = windows }

        func queryWindows() -> [GlazeWindow] {
            queryCount += 1
            return windows
        }
        // Never emits — the test drives reconcile() directly.
        func subscribe(events: [String], onEvent: @escaping @Sendable (GlazeWindow?) -> Void) {}
    }

    private func focusedWindow() -> GlazeWindow {
        GlazeWindow(id: "w1", processName: "Alacritty", hasFocus: true,
                    x: 0, y: 0, width: 100, height: 100,
                    state: .init(type: "tiling"), displayState: "shown")
    }

    @Test("startup queries once to seed, then stops re-querying")
    func queriesOnceThenSeeds() {
        let source = CountingSource(windows: [focusedWindow()])
        let daemon = Daemon(cfg: Config(), glaze: source)

        // Drive several reconciles as the poll would, with no events delivered.
        for _ in 0..<5 { daemon.reconcile() }

        // The first reconcile queries (cache empty) and seeds latestFocused; the
        // rest reuse the cache. So exactly one query total, not one per reconcile.
        #expect(source.queryCount == 1, "expected a single seeding query, got \(source.queryCount)")
    }

    @Test("an event-supplied focused window means no startup query at all")
    func eventBeforeReconcileSkipsQuery() {
        let source = CountingSource(windows: [focusedWindow()])
        let daemon = Daemon(cfg: Config(), glaze: source)

        // Simulate a GlazeWM event arriving first (populates latestFocused),
        // then reconciles. The cache is already warm, so no query happens.
        daemon.scheduleReconcile(focused: focusedWindow())
        for _ in 0..<3 { daemon.reconcile() }

        #expect(source.queryCount == 0, "a pre-seeded cache should need no query, got \(source.queryCount)")
    }
}
