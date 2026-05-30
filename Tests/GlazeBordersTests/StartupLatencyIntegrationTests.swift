import Testing
import CoreGraphics
import AppKit
import Foundation
@testable import GlazeBordersCore

/// LIVE: the daemon should paint a border shortly after launch, not after the
/// first manual focus change. Launches the real binary and measures the time
/// until a border overlay appears on screen. Complements the overlay smoke test
/// with a startup-latency guard. Gated on the live environment + installed binary.
@Suite("Integration: startup latency")
@MainActor
struct StartupLatencyIntegrationTests {
    init() throws { try IntegrationEnvironment.require() }

    @Test("border appears within budget of daemon launch")
    func paintsOnStartup() throws {
        let binary = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/bin/glaze-borders")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { return }

        let proc = Process()
        proc.executableURL = binary
        let start = DispatchTime.now()
        try proc.run()
        defer { proc.terminate() }

        // Poll until the daemon's overlay window appears (or time out).
        var appearedMs: Double?
        while elapsedMs(since: start) < 2000 {
            if overlayExists(ownedBy: proc.processIdentifier) {
                appearedMs = elapsedMs(since: start)
                break
            }
            usleep(2000)
        }

        let ms = try #require(appearedMs, "no border overlay appeared within 2s of launch")
        // Generous budget: launch + sub connect + initial query/AX + draw. ~hundreds
        // of ms in practice; 1500ms is the regression alarm.
        #expect(ms < 1500, "border took \(Int(ms))ms to appear on startup")
    }

    // MARK: - helpers

    private func overlayExists(ownedBy pid: pid_t) -> Bool {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: Any]] else { return false }
        return info.contains { ($0[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid }
    }

    private func elapsedMs(since t: DispatchTime) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - t.uptimeNanoseconds) / 1_000_000
    }
}
