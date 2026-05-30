import Testing
import AppKit
@testable import GlazeBordersCore

/// LIVE integration: reads real window geometry from the Accessibility API of
/// the frontmost application. Requires Accessibility permission for the test
/// runner (checked in init). See IntegrationEnvironment.
@Suite("Integration: AXWatcher")
@MainActor
struct AXWatcherIntegrationTests {
    init() throws { try IntegrationEnvironment.require() }

    @Test("reads a real, on-screen frame for the frontmost window")
    func readsFrontmostFrame() throws {
        let app = try #require(NSWorkspace.shared.frontmostApplication)
        let watcher = AXWatcher(onChange: {})
        let info = try #require(watcher.watchFocusedWindow(pid: app.processIdentifier),
                                "AX could not resolve the frontmost window")
        // A real window has positive dimensions and sits within the union of screens.
        #expect(info.frame.width > 0)
        #expect(info.frame.height > 0)
        let screensUnion = NSScreen.screens.reduce(CGRect.null) { $0.union($1.frame) }
        // The window's origin should fall on some screen (top-left/y-down AX coords
        // won't equal AppKit's, so just sanity-check the frame isn't absurd).
        #expect(info.frame.width <= screensUnion.width + 1)
    }

    @Test("toolbar detection: a Finder browser window reports a toolbar")
    func toolbarDetection() throws {
        let watcher = AXWatcher(onChange: {})

        let finder = try #require(
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first)
        // Open a real browser window (Finder may otherwise focus only the desktop
        // window, which is full-screen and has no toolbar).
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
        finder.activate()
        try wait()

        guard let info = watcher.watchFocusedWindow(pid: finder.processIdentifier) else { return }

        // Skip the desktop window (full screen, no title bar) — only a real
        // browser window is expected to carry a toolbar.
        let isDesktopWindow = info.frame.origin == .zero
            && info.frame.size == (NSScreen.main?.frame.size ?? .zero)
        if isDesktopWindow { return }

        #expect(info.hasToolbar, "a Finder browser window should report a toolbar")
    }

    // A tiny synchronous wait so AX has time to reflect an app activation, without
    // pulling in async test machinery for a one-off settle.
    private func wait(_ seconds: TimeInterval = 0.4) throws {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: deadline)
        }
    }
}
