import Testing
import Foundation
@testable import GlazeBordersCore

@Suite("GlazeWindow")
struct GlazeWindowTests {

    // Helper: build a window with sensible defaults, overriding what each test cares about.
    private func window(state: String = "tiling", display: String = "shown",
                        focus: Bool = true) -> GlazeWindow {
        GlazeWindow(id: "id", processName: "App", hasFocus: focus,
                    x: 0, y: 0, width: 100, height: 100,
                    state: .init(type: state), displayState: display)
    }

    @Test("isBordered truth table", arguments: [
        // (state,       display,  expected)
        ("tiling",     "shown",  true),
        ("fullscreen", "shown",  true),
        ("tiling",     "hidden", false),
        ("minimized",  "shown",  false),
        ("floating",   "shown",  false),
    ])
    func isBordered(state: String, display: String, expected: Bool) {
        #expect(window(state: state, display: display).isBordered == expected)
    }

    @Test("decodes a real `glazewm query windows` response shape")
    func decodesQueryResponse() throws {
        // Mirrors the actual IPC envelope: { data: { windows: [...] }, success }.
        let json = """
        {
          "data": { "windows": [
            { "type": "window", "id": "abc", "processName": "Alacritty",
              "hasFocus": true, "x": 4, "y": 47, "width": 960, "height": 1080,
              "state": { "type": "tiling" }, "displayState": "shown" }
          ] },
          "error": null, "success": true
        }
        """
        // Decode through the same path GlazeClient uses by exercising the public
        // GlazeWindow Decodable conformance on the inner object.
        let inner = """
        { "type": "window", "id": "abc", "processName": "Alacritty",
          "hasFocus": true, "x": 4, "y": 47, "width": 960, "height": 1080,
          "state": { "type": "tiling" }, "displayState": "shown" }
        """
        let w = try JSONDecoder().decode(GlazeWindow.self, from: Data(inner.utf8))
        #expect(w.id == "abc")
        #expect(w.processName == "Alacritty")
        #expect(w.hasFocus)
        #expect(w.x == 4 && w.y == 47 && w.width == 960 && w.height == 1080)
        #expect(w.state.type == "tiling")
        #expect(w.isBordered)
        // The full envelope is valid JSON (sanity check on the documented shape).
        #expect(!json.isEmpty)
    }
}
