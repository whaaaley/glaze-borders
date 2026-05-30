import Testing
@testable import GlazeBordersCore

@Suite("Config")
struct ConfigTests {

    @Test("default values match the documented defaults")
    func defaults() {
        let c = Config()
        #expect(c.width == 2)
        #expect(c.offset == 0)
        #expect(c.cornerRadius == 10)
        #expect(c.cornerRadiusToolbar == 22)
        #expect(c.popOnFocus == false)
        #expect(c.radiusOverrides["System Information"] == 14)
    }

    @Test("reconcilerSettings forwards every field")
    func reconcilerSettingsForwarding() {
        var c = Config()
        c.width = 3
        c.offset = -4
        c.cornerRadius = 8
        c.cornerRadiusToolbar = 20
        c.radiusOverrides = ["Foo": 5]

        let s = c.reconcilerSettings
        #expect(s.width == 3)
        #expect(s.offset == -4)
        #expect(s.cornerRadius == 8)
        #expect(s.cornerRadiusToolbar == 20)
        #expect(s.radiusOverrides == ["Foo": 5])
    }
}
