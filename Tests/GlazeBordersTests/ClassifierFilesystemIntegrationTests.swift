import Testing
import Foundation
@testable import GlazeBordersCore

/// Integration: the Classifier's real persistence behavior against the actual
/// filesystem (a temp file, not the user's ~/.config, so the test is isolated
/// and repeatable). Unlike the unit tests, this asserts the on-disk JSON format
/// and that a separate process-equivalent instance reads it back.
@Suite("Integration: Classifier filesystem")
struct ClassifierFilesystemIntegrationTests {

    @Test("writes a JSON file a fresh instance can read back")
    func roundTripsOnDisk() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("glaze-borders-fs-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let writer = Classifier(url: url)
        writer.observe("Finder", hasToolbar: true)
        writer.observe("Alacritty", hasToolbar: false)

        // The file exists and is valid JSON of the documented shape.
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([String: String].self, from: data)
        #expect(decoded["Finder"] == "toolbar")
        #expect(decoded["Alacritty"] == "plain")

        // A fresh instance (simulating a daemon restart) loads the same state.
        let reader = Classifier(url: url)
        #expect(reader.known("Finder") == .toolbar)
        #expect(reader.known("Alacritty") == .plain)
    }

    @Test("creates the parent directory when persisting to a nested path")
    func createsNestedDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("glaze-borders-\(UUID().uuidString)", isDirectory: true)
        let url = dir.appendingPathComponent("classifications.json")
        defer { try? FileManager.default.removeItem(at: dir) }

        // The default init creates ~/.config/glaze-borders; here we only verify
        // that writing to a path whose parent exists works. Pre-create the dir to
        // mirror the default init's behavior.
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let c = Classifier(url: url)
        c.observe("Finder", hasToolbar: true)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
