import Testing
import CoreGraphics
import AppKit
import Foundation
@testable import GlazeBordersCore

/// END-TO-END switch latency: the number a user actually feels. Launches the
/// real daemon, switches focus between apps, and measures the wall-clock time
/// from issuing the switch to the border overlay actually moving on screen.
///
/// This is the canonical performance test — unlike the piece-wise benchmarks, it
/// captures the whole chain: sub event -> settle debounce -> query+AX gather ->
/// AppKit draw. Gated on the live environment + an installed daemon binary.
@Suite("Benchmarks: end-to-end switch latency")
@MainActor
struct E2ELatencyBenchmarkTests {
    init() throws { try IntegrationEnvironment.require() }

    @Test("focus switch redraws the border within budget")
    func switchLatency() throws {
        let binary = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/bin/glaze-borders")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { return }

        // Two apps to bounce focus between. Both must be running for a real switch.
        let names = ["Alacritty", "Google Chrome", "Finder"]
        let running = names.compactMap { name in
            NSWorkspace.shared.runningApplications.first { $0.localizedName == name }
        }
        try #require(running.count >= 2, "need at least two of \(names) running to measure a switch")

        let proc = Process()
        proc.executableURL = binary
        try proc.run()
        defer { proc.terminate() }
        spin(1.5)   // let it draw the initial border

        var samples: [Double] = []
        let dirs = ["right", "left"]
        for i in 0..<6 {
            let before = overlayFrame(of: proc.processIdentifier)
            let start = DispatchTime.now()
            // Trigger the switch the way the user does — GlazeWM's own focus
            // command — so we measure GlazeWM's event pipeline too, not just an
            // NSWorkspace activation (which bypasses it and undercounts).
            glazeFocus(dirs[i % dirs.count])

            // Poll until the overlay frame changes (or time out at 3s).
            while elapsedMs(since: start) < 3000 {
                if let f = overlayFrame(of: proc.processIdentifier), f != before { break }
                usleep(1000)
            }
            if i > 0 { samples.append(elapsedMs(since: start)) }   // drop warmup
            spin(0.4)
        }

        try #require(!samples.isEmpty, "no border movement observed on switch")
        let median = samples.sorted()[samples.count / 2]
        // REAL felt latency, measured from a genuine `glazewm command focus`.
        // Baseline today is ~195ms (80ms settle debounce + ~40ms glazewm query +
        // GlazeWM's own pipeline + draw). 250ms is the regression alarm; the perf
        // work (immediate focus handling + sub-payload parsing) targets <100ms.
        #expect(median < 250, "median switch latency \(median)ms; samples=\(samples)")
    }

    // MARK: - helpers

    private func overlayFrame(of pid: pid_t) -> CGRect? {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: Any]] else { return nil }
        guard let w = info.first(where: { ($0[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid }),
              let b = w[kCGWindowBounds as String] as? [String: Any],
              let x = b["X"] as? CGFloat, let y = b["Y"] as? CGFloat,
              let width = b["Width"] as? CGFloat, let height = b["Height"] as? CGFloat
        else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func elapsedMs(since t: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - t.uptimeNanoseconds) / 1_000_000
    }

    private func glazeFocus(_ direction: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/glazewm")
        p.arguments = ["command", "focus", "--direction", direction]
        try? p.run()
        p.waitUntilExit()
    }

    private func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline { RunLoop.current.run(mode: .default, before: deadline) }
    }
}
