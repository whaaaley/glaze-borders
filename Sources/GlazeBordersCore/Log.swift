import Foundation

/// Dead-simple debug logger. Appends a line to /tmp/glaze-borders.debug.log,
/// gated by GLAZE_BORDERS_DEBUG=1 so it costs nothing in normal use.
///
/// Uses O_APPEND each write (not a cached FileHandle offset) so external
/// truncation of the file (e.g. `: > logfile` during testing) can't leave null
/// gaps — every write goes to the true current end.
enum Log {
    static let enabled = ProcessInfo.processInfo.environment["GLAZE_BORDERS_DEBUG"] == "1"
    private static let path = "/tmp/glaze-borders.debug.log"

    static func line(_ msg: String) {
        guard enabled else { return }
        let data = Data((msg + "\n").utf8)
        let fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0o644)
        guard fd >= 0 else { return }
        defer { close(fd) }
        data.withUnsafeBytes { _ = write(fd, $0.baseAddress, data.count) }
    }
}
