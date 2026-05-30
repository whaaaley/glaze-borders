import Testing
import CoreGraphics
@testable import GlazeBordersCore

@Suite("RadiusResolver")
struct RadiusResolverTests {
    private let config = RadiusResolver.Config(
        plain: 10,
        toolbar: 22,
        overrides: ["System Information": 14])

    @Test("plain window gets the plain radius")
    func plain() {
        #expect(RadiusResolver.radius(app: "Alacritty", isToolbar: false, config: config) == 10)
    }

    @Test("toolbar window gets the toolbar radius")
    func toolbar() {
        #expect(RadiusResolver.radius(app: "Finder", isToolbar: true, config: config) == 22)
    }

    @Test("per-app override wins over the class default", arguments: [true, false])
    func overrideWins(isToolbar: Bool) {
        // The override applies regardless of toolbar classification.
        #expect(RadiusResolver.radius(app: "System Information", isToolbar: isToolbar, config: config) == 14)
    }

    @Test("unknown app with no override falls back to plain")
    func unknownFallsBackToPlain() {
        #expect(RadiusResolver.radius(app: "Whatever", isToolbar: false, config: config) == 10)
    }
}
