import Testing
import CoreGraphics
import Foundation
@testable import GlazeBordersCore

/// Performance benchmarks for the hot paths that run on every focus/move event.
///
/// These assert a generous per-call budget so they double as regression guards:
/// if a change makes the reconcile path materially slower, a benchmark fails.
/// Budgets are deliberately loose (CI machines vary) — they catch order-of-
/// magnitude regressions, not micro-fluctuations. The pure benchmarks here have
/// no I/O; live AX/IPC timing lives in the gated integration benchmarks below.
@Suite("Benchmarks: pure hot path")
struct PureBenchmarkTests {
    private let iterations = 10_000

    private func windows(_ n: Int) -> [GlazeWindow] {
        (0..<n).map { i in
            GlazeWindow(id: "w\(i)", processName: "App\(i)", hasFocus: i == 0,
                        x: i * 10, y: 0, width: 100, height: 100,
                        state: .init(type: "tiling"), displayState: "shown")
        }
    }

    private func measureMs(_ body: () -> Void) -> Double {
        let start = DispatchTime.now()
        body()
        let ns = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds)
        return ns / 1_000_000
    }

    @Test("Reconciler.decide stays well under budget over many windows")
    func decideThroughput() {
        let wins = windows(20)
        let front = Reconciler.Input.Front(app: "App0",
                                           frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                           hasToolbar: false)
        let input = Reconciler.Input(windows: wins, front: front, screenFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        let settings = Config().reconcilerSettings

        let ms = measureMs {
            for _ in 0..<iterations {
                _ = Reconciler.decide(input, config: settings, classify: { _ in nil })
            }
        }
        let perCall = ms / Double(iterations)
        // ~microseconds per call in practice; 0.1ms is a very loose ceiling.
        #expect(perCall < 0.1, "Reconciler.decide averaged \(perCall)ms/call")
    }

    @Test("Geometry.placement is effectively free")
    func geometryThroughput() {
        let glaze = CGRect(x: 4, y: 47, width: 960, height: 1080)
        let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let ms = measureMs {
            for _ in 0..<iterations {
                _ = Geometry.placement(windowFrame: glaze, screenFrame: screen, width: 2, offset: 0)
            }
        }
        #expect(ms / Double(iterations) < 0.05)
    }

    @Test("ScreenPick scales fine across several displays")
    func screenPickThroughput() {
        let screens = (0..<4).map { CGRect(x: $0 * 1920, y: 0, width: 1920, height: 1080) }
        let win = CGRect(x: 3000, y: 100, width: 800, height: 600)
        let ms = measureMs {
            for _ in 0..<iterations {
                _ = ScreenPick.best(for: win, among: screens)
            }
        }
        #expect(ms / Double(iterations) < 0.05)
    }
}
