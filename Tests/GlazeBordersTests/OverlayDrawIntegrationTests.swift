import Testing
import CoreGraphics
import AppKit
import Foundation
@testable import GlazeBordersCore

/// LIVE end-to-end smoke test: launches the real daemon binary, lets it draw,
/// and confirms a border overlay window actually appears on screen (discovered
/// via CGWindowList). This exercises the full path — GlazeWM IPC, AX, the
/// reconciler, and AppKit overlay creation — that the unit tests stub out.
///
/// Requires GlazeWM running and the daemon binary built. Skips cleanly if the
/// binary is missing (run `make install` or `make release` first).
@Suite("Integration: overlay draw")
@MainActor
struct OverlayDrawIntegrationTests {
    init() throws { try IntegrationEnvironment.require() }

    @Test("the daemon draws exactly one focused-window overlay")
    func drawsOneOverlay() throws {
        let binary = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/bin/glaze-borders")
        guard FileManager.default.isExecutableFile(atPath: binary.path) else {
            // Binary not installed; nothing to smoke-test this run.
            return
        }

        // Launch the real daemon.
        let proc = Process()
        proc.executableURL = binary
        try proc.run()
        defer { proc.terminate() }

        // Give it time to subscribe, query, and draw the initial border.
        spin(1.5)

        // Count on-screen windows owned by the daemon process.
        let overlays = onScreenWindowCount(ownedBy: proc.processIdentifier)
        #expect(overlays == 1, "expected exactly one border overlay, found \(overlays)")
    }

    // MARK: - helpers

    private func onScreenWindowCount(ownedBy pid: pid_t) -> Int {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: Any]] else { return 0 }
        return info.filter {
            ($0[kCGWindowOwnerPID as String] as? Int).map(pid_t.init) == pid
        }.count
    }

    // Pump the run loop so the launched process can draw, without async machinery.
    private func spin(_ seconds: TimeInterval) {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: deadline)
        }
    }
}
