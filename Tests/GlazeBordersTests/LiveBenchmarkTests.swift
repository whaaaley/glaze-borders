import Testing
import AppKit
import Foundation
@testable import GlazeBordersCore

/// Live benchmarks for the per-event I/O that drives switch latency: the
/// `glazewm query windows` subprocess and the AX focused-window read (including
/// the toolbar-child enumeration). These are what actually cost wall-clock time
/// when you switch windows, so a regression here is felt directly.
///
/// Budgets are loose and machine-dependent; they flag gross regressions, not
/// jitter. Gated on the live environment (GlazeWM + Accessibility).
@Suite("Benchmarks: live I/O")
@MainActor
struct LiveBenchmarkTests {
    init() throws { try IntegrationEnvironment.require() }

    private func measureAvgMs(_ n: Int, _ body: () -> Void) -> Double {
        let start = DispatchTime.now()
        for _ in 0..<n { body() }
        let ns = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
        return ns / 1_000_000 / Double(n)
    }

    @Test("glazewm query windows averages under budget")
    func queryWindowsLatency() {
        let client = GlazeClient()
        let avg = measureAvgMs(20) { _ = client.queryWindows() }
        // KNOWN SLOW PATH: GlazeWM's `query windows` IPC currently runs ~40-85ms
        // per call, and reconcile spawns it on every event — this is the cause of
        // laggy window switching (see perf task: parse the sub event payload
        // instead). Budget set above the measured baseline so it guards against
        // further regression; tighten it once the query is off the hot path.
        #expect(avg < 150, "glazewm query windows averaged \(avg)ms")
    }

    @Test("AX focused-window read (with toolbar detection) averages under budget")
    func axReadLatency() throws {
        let app = try #require(NSWorkspace.shared.frontmostApplication)
        let watcher = AXWatcher(onChange: {})
        let avg = measureAvgMs(20) { _ = watcher.watchFocusedWindow(pid: app.processIdentifier) }
        // Each call is an AX round-trip plus child enumeration; tens of ms is the alarm line.
        #expect(avg < 30, "watchFocusedWindow averaged \(avg)ms")
    }

    @Test("a full reconcile-equivalent gather is under one frame budget")
    func fullGatherLatency() throws {
        let client = GlazeClient()
        let app = try #require(NSWorkspace.shared.frontmostApplication)
        let watcher = AXWatcher(onChange: {})
        // Mirror what the daemon does per event: query + AX read + screen list.
        let avg = measureAvgMs(20) {
            _ = client.queryWindows()
            _ = watcher.watchFocusedWindow(pid: app.processIdentifier)
            _ = NSScreen.screens.map(\.frame)
        }
        // Dominated by the ~40-85ms `glazewm query windows` IPC (see the perf
        // task to remove it from the hot path). Budget guards against regression
        // beyond today's baseline; the daemon's 0.08s settle debounce is a
        // SEPARATE intentional delay and is not measured here.
        #expect(avg < 180, "per-event gather averaged \(avg)ms")
    }
}
