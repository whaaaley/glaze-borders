import Testing
import Foundation
@testable import GlazeBordersCore

@Suite("Classifier")
struct ClassifierTests {
    // A unique temp file per test so persistence tests don't collide.
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("glaze-borders-test-\(UUID().uuidString).json")
    }

    @Test("unknown app is nil until observed")
    func unknownIsNil() {
        let c = Classifier(url: tempURL())
        #expect(c.known("Nope") == nil)
    }

    @Test("observe records plain and toolbar")
    func observeRecords() {
        let c = Classifier(url: tempURL())
        #expect(c.observe("Alacritty", hasToolbar: false) == .plain)
        #expect(c.known("Alacritty") == .plain)
        #expect(c.observe("Finder", hasToolbar: true) == .toolbar)
        #expect(c.known("Finder") == .toolbar)
    }

    // The one-way gate is what kills radius flicker from transient AX misses.
    @Test("toolbar is sticky: a later plain observation does not downgrade it")
    func toolbarSticky() {
        let c = Classifier(url: tempURL())
        #expect(c.observe("Finder", hasToolbar: true) == .toolbar)
        #expect(c.observe("Finder", hasToolbar: false) == .toolbar)  // AX missed; stays toolbar
        #expect(c.known("Finder") == .toolbar)
    }

    @Test("persists across instances at the same path")
    func persistsAcrossInstances() {
        let url = tempURL()
        let first = Classifier(url: url)
        first.observe("Finder", hasToolbar: true)
        first.observe("Alacritty", hasToolbar: false)

        // A fresh instance reads the saved file.
        let second = Classifier(url: url)
        #expect(second.known("Finder") == .toolbar)
        #expect(second.known("Alacritty") == .plain)
    }

    @Test("missing file yields an empty, non-crashing classifier")
    func missingFileIsEmpty() {
        let c = Classifier(url: tempURL())   // path does not exist yet
        #expect(c.known("anything") == nil)
    }
}
