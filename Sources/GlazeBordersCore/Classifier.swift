import Foundation

/// Persistent, one-way window-type classification keyed by app name.
///
/// AX toolbar detection occasionally misses on a given tick, which would flip a
/// toolbar window's corner radius back to the plain value. This caches the
/// result by app: once any window of an app is seen with a toolbar, that app is
/// "toolbar" forever — across window instances AND daemon restarts. The gate is
/// one-way (toolbar can never downgrade to plain), so a transient AX miss can't
/// undo a known-good classification. It also makes the FIRST focus of a known
/// app instant-correct, with no AX race.
///
/// Stored at ~/.config/glaze-borders/classifications.json:
///   { "System Settings": "toolbar", "Alacritty": "plain" }
public final class Classifier {
    public enum Kind: String { case toolbar, plain }

    private var map: [String: Kind] = [:]
    private let url: URL

    /// - Parameter url: where to persist. Defaults to
    ///   ~/.config/glaze-borders/classifications.json; tests inject a temp path.
    public init(url: URL? = nil) {
        if let url {
            self.url = url
        } else {
            let dir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config/glaze-borders", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            } catch {
                Log.line("classifier: could not create \(dir.path): \(error)")
            }
            self.url = dir.appendingPathComponent("classifications.json")
        }
        load()
    }

    /// The known classification for an app, or nil if never seen.
    public func known(_ app: String) -> Kind? { map[app] }

    /// Record an observation. One-way: an app marked `toolbar` never downgrades.
    /// Returns the effective (possibly sticky) classification.
    @discardableResult
    public func observe(_ app: String, hasToolbar: Bool) -> Kind {
        if map[app] == .toolbar { return .toolbar }   // sticky, never downgrade
        let kind: Kind = hasToolbar ? .toolbar : .plain
        if map[app] != kind {
            map[app] = kind
            save()
        }
        return kind
    }

    // MARK: - persistence

    private func load() {
        // A missing file is normal on first run — only a present-but-unreadable or
        // corrupt file is worth surfacing.
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let raw = try JSONDecoder().decode([String: String].self, from: data)
            for (k, v) in raw { if let kind = Kind(rawValue: v) { map[k] = kind } }
        } catch {
            Log.line("classifier: could not load \(url.path): \(error)")
        }
    }

    private func save() {
        do {
            let raw = map.mapValues { $0.rawValue }
            try JSONEncoder().encode(raw).write(to: url)
        } catch {
            Log.line("classifier: could not save \(url.path): \(error)")
        }
    }
}
