import Testing
import CoreGraphics
@testable import GlazeBordersCore

@Suite("Reconciler")
struct ReconcilerTests {
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    private let settings = Reconciler.Settings(
        width: 2, offset: 0, cornerRadius: 10, cornerRadiusToolbar: 22,
        radiusOverrides: ["System Information": 14])

    private func win(_ id: String, focus: Bool, x: Int = 0, w: Int = 100,
                     proc: String = "App", state: String = "tiling") -> GlazeWindow {
        GlazeWindow(id: id, processName: proc, hasFocus: focus,
                    x: x, y: 0, width: w, height: 100,
                    state: .init(type: state), displayState: "shown")
    }

    private func decide(_ input: Reconciler.Input,
                        classify: @escaping (String) -> Classifier.Kind? = { _ in nil }) -> Reconciler.Command? {
        Reconciler.decide(input, config: settings, classify: classify)
    }

    @Test("no focused bordered window yields no command")
    func noFocusNoCommand() {
        let input = Reconciler.Input(windows: [win("a", focus: false)], front: nil, screenFrame: screen)
        #expect(decide(input) == nil)
    }

    @Test("missing screen frame yields no command")
    func noScreenNoCommand() {
        let input = Reconciler.Input(windows: [win("a", focus: true)], front: nil, screenFrame: nil)
        #expect(decide(input) == nil)
    }

    @Test("falls back to the GlazeWM frame when AX did not resolve")
    func glazeFallback() {
        let w = win("a", focus: true, x: 4, w: 960)
        let input = Reconciler.Input(windows: [w], front: nil, screenFrame: screen)
        let cmd = decide(input)
        // Placement is derived from the glaze frame (x=4, width=960).
        #expect(cmd?.windowId == "a")
        #expect(cmd?.placement.windowFrame.origin.x == 4)
        #expect(cmd?.placement.windowFrame.width == 960)
    }

    // Regression for bug #1: a min-size app overflows its tile, so its real AX
    // frame is wider than what GlazeWM reports. The border must follow the AX frame.
    @Test("prefers the AX frame over the GlazeWM frame when both are present")
    func axFramePreferred() {
        let glaze = win("a", focus: true, x: 0, w: 427, proc: "Google Chrome")
        let axFrame = CGRect(x: 0, y: 0, width: 620, height: 100)   // real, wider
        let front = Reconciler.Input.Front(app: "Google Chrome", frame: axFrame, hasToolbar: false)
        let input = Reconciler.Input(windows: [glaze], front: front, screenFrame: screen)
        let cmd = decide(input)
        // Drawn at the AX width (620), not GlazeWM's 427.
        #expect(cmd?.placement.windowFrame.width == 620)
    }

    // Regression for bug #5: a floating window (About This Mac / System Information)
    // is frontmost while GlazeWM still reports a different tiled window focused.
    // Classification + radius must key off the FRONTMOST app, not GlazeWM's window.
    @Test("classifies by the frontmost app, not the GlazeWM window")
    func classifyByFrontmostApp() {
        let glaze = win("term", focus: true, proc: "Alacritty")   // GlazeWM thinks Alacritty
        let front = Reconciler.Input.Front(app: "System Information",
                                           frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                           hasToolbar: false)
        let input = Reconciler.Input(windows: [glaze], front: front, screenFrame: screen)
        // System Information has a per-app override of 14 (keyed by the frontmost app name).
        #expect(decide(input)?.cornerRadius == 14)
    }

    @Test("toolbar classification selects the toolbar radius")
    func toolbarRadius() {
        let glaze = win("f", focus: true, proc: "Finder")
        let front = Reconciler.Input.Front(app: "Finder",
                                           frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                                           hasToolbar: true)
        let input = Reconciler.Input(windows: [glaze], front: front, screenFrame: screen)
        #expect(decide(input, classify: { $0 == "Finder" ? .toolbar : nil })?.cornerRadius == 22)
    }

    @Test("command carries the GlazeWM window id for focus tracking")
    func windowIdFromGlaze() {
        let input = Reconciler.Input(windows: [win("the-id", focus: true)], front: nil, screenFrame: screen)
        #expect(decide(input)?.windowId == "the-id")
    }
}
