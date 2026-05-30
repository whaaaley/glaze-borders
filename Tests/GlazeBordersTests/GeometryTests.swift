import Testing
import CoreGraphics
@testable import GlazeBordersCore

/// Unit tests for the pure border-placement math — the class of logic that
/// caused every "border is offset" bug, so it gets exhaustive I/O-table coverage.
@Suite("Geometry")
struct GeometryTests {

    // A 100x100 window at top-left (0,0) on a 1000-tall screen.
    // After the y-flip, its bottom-left origin y = 1000 - (0 + 100) = 900.
    private let glaze = CGRect(x: 0, y: 0, width: 100, height: 100)
    private let screen = CGRect(x: 0, y: 0, width: 1000, height: 1000)

    @Test("pure-inner border: stroke fully inside the window edge")
    func pureInner() {
        let p = Geometry.placement(windowFrame: glaze, screenFrame: screen,
                                   width: 4, offset: 0)
        // offset 0 => overlay == window frame (no grow).
        #expect(p.windowFrame == CGRect(x: 0, y: 900, width: 100, height: 100))
        // Stroke centered on a path inset by half the width (2) => outer edge
        // flush with the window edge.
        #expect(p.pathRect == CGRect(x: 2, y: 2, width: 96, height: 96))
    }

    @Test("negative offset pushes the border outward")
    func outwardOffset() {
        let p = Geometry.placement(windowFrame: glaze, screenFrame: screen,
                                   width: 4, offset: -4)
        // outward=4 => overlay grows 4 on each side: origin -4, size +8.
        #expect(p.windowFrame == CGRect(x: -4, y: 896, width: 108, height: 108))
        // pathInset = (grow - outward) + half = (4-4)+2 = 2.
        #expect(p.pathRect == CGRect(x: 2, y: 2, width: 104, height: 104))
    }

    @Test("y-flip uses screen height", arguments: [
        // (windowY, windowH, screenH, expectedFlippedY)
        (0,   100, 1000, 900.0),
        (50,  100, 1000, 850.0),
        (0,   200, 800,  600.0),
    ])
    func yFlip(windowY: Int, windowH: Int, screenH: Int, expected: CGFloat) {
        let w = CGRect(x: 0, y: CGFloat(windowY), width: 100, height: CGFloat(windowH))
        let s = CGRect(x: 0, y: 0, width: 1000, height: CGFloat(screenH))
        let p = Geometry.placement(windowFrame: w, screenFrame: s, width: 2, offset: 0)
        #expect(p.windowFrame.origin.y == expected)
    }

    @Test("multi-screen: window frame is offset by the screen origin")
    func multiScreenOrigin() {
        // A second screen to the right at x=1000.
        let s = CGRect(x: 1000, y: 0, width: 800, height: 1000)
        let p = Geometry.placement(windowFrame: glaze, screenFrame: s, width: 2, offset: 0)
        #expect(p.windowFrame.origin.x == 1000)   // shifted into the right screen
    }
}
