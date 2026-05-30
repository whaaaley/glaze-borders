import Testing
import CoreGraphics
@testable import GlazeBordersCore

@Suite("EnvParse")
struct EnvParseTests {
    @Test("cgFloat parses a valid number")
    func parsesValid() {
        #expect(EnvParse.cgFloat(["R": "12.5"], "R") == CGFloat(12.5))
        #expect(EnvParse.cgFloat(["R": "0"], "R") == CGFloat(0))
        #expect(EnvParse.cgFloat(["R": "-3"], "R") == CGFloat(-3))
    }

    @Test("cgFloat returns nil when the key is missing")
    func missingKey() {
        #expect(EnvParse.cgFloat([:], "R") == nil)
        #expect(EnvParse.cgFloat(["OTHER": "5"], "R") == nil)
    }

    @Test("cgFloat returns nil for non-numeric values")
    func nonNumeric() {
        #expect(EnvParse.cgFloat(["R": ""], "R") == nil)
        #expect(EnvParse.cgFloat(["R": "abc"], "R") == nil)
        #expect(EnvParse.cgFloat(["R": "1.2.3"], "R") == nil)
    }

    @Test("flag is true only for exactly \"1\"")
    func flag() {
        #expect(EnvParse.flag(["P": "1"], "P") == true)
        #expect(EnvParse.flag(["P": "0"], "P") == false)
        #expect(EnvParse.flag(["P": "true"], "P") == false)
        #expect(EnvParse.flag([:], "P") == false)
    }
}

@Suite("ScreenPick")
struct ScreenPickTests {
    private let main = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    // A shorter screen to the right (the case that broke the y-flip).
    private let right = CGRect(x: 1000, y: 0, width: 1200, height: 800)

    @Test("picks the screen the window overlaps most")
    func picksOverlapping() {
        let win = CGRect(x: 1100, y: 100, width: 200, height: 200)  // on `right`
        #expect(ScreenPick.best(for: win, among: [main, right]) == right)
    }

    @Test("a window mostly on the main screen picks the main screen")
    func picksMain() {
        let win = CGRect(x: 10, y: 10, width: 200, height: 200)
        #expect(ScreenPick.best(for: win, among: [main, right]) == main)
    }

    @Test("straddling: picks the side with the larger overlap area")
    func straddle() {
        // 300 wide spanning x=900..1200: 100 on main, 200 on right => right wins.
        let win = CGRect(x: 900, y: 0, width: 300, height: 100)
        #expect(ScreenPick.best(for: win, among: [main, right]) == right)
    }

    @Test("no overlap falls back to the first screen")
    func noOverlap() {
        let win = CGRect(x: 5000, y: 5000, width: 10, height: 10)
        #expect(ScreenPick.best(for: win, among: [main, right]) == main)
    }

    @Test("no screens returns nil")
    func empty() {
        #expect(ScreenPick.best(for: main, among: []) == nil)
    }
}
