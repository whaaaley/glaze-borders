import Foundation

// MARK: - GlazeWM data model
//
// We only decode the fields we actually use. GlazeWM reports window frames in a
// TOP-LEFT origin, y-DOWN coordinate space (y=47 is just below the menu bar).
// AppKit is bottom-left / y-up — the conversion happens in Overlay, not here.

/// A window as reported by `glazewm query windows`.
public struct GlazeWindow: Decodable, Equatable {
    public let id: String
    public let processName: String
    public let hasFocus: Bool
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let state: State
    public let displayState: String

    public struct State: Decodable, Equatable {
        public let type: String
        public init(type: String) { self.type = type }
    }

    public init(id: String, processName: String, hasFocus: Bool,
                x: Int, y: Int, width: Int, height: Int,
                state: State, displayState: String) {
        self.id = id
        self.processName = processName
        self.hasFocus = hasFocus
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.state = state
        self.displayState = displayState
    }

    /// Tiling or fullscreen windows that are currently shown get a border.
    /// (Fullscreen included so the focused border follows a window into alt+f.)
    public var isBordered: Bool {
        (state.type == "tiling" || state.type == "fullscreen") && displayState == "shown"
    }
}

/// Envelope shared by every glazewm IPC response: `{ data, error, success }`.
private struct Envelope<T: Decodable>: Decodable {
    let data: T
    let success: Bool
    let error: String?
}

private struct WindowsQuery: Decodable { let windows: [GlazeWindow] }

/// Thin client around the `glazewm` CLI: a one-shot `query windows`, and a
/// long-lived `sub` stream whose every line is just a nudge to re-query.
public final class GlazeClient: Sendable {
    private let binary: String
    public init(binary: String = "/opt/homebrew/bin/glazewm") { self.binary = binary }

    /// Authoritative snapshot of all windows. Returns [] on any failure so the
    /// daemon degrades to "no borders" rather than crashing.
    func queryWindows() -> [GlazeWindow] {
        guard let out = run(["query", "windows"]),
              let data = out.data(using: .utf8) else { return [] }
        do {
            let env = try JSONDecoder().decode(Envelope<WindowsQuery>.self, from: data)
            guard env.success else {
                Log.line("glazewm query windows reported failure: \(env.error ?? "unknown")")
                return []
            }
            return env.data.windows
        } catch {
            Log.line("glazewm query windows decode failed: \(error)")
            return []
        }
    }

    /// Spawns `glazewm sub` and calls `onEvent` for every line received. Blocks
    /// the calling thread; run it on a background queue. Returns when the
    /// subprocess exits (caller is expected to restart it).
    func subscribe(events: [String], onEvent: @escaping @Sendable () -> Void) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = ["sub", "--events"] + events
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            guard !chunk.isEmpty else { return }
            // Every line in the chunk is one event, but the exact count doesn't
            // matter: `onEvent` is a coalesced nudge to re-query, so a line split
            // across two reads (over- or under-counting by one) is harmless.
            guard let s = String(data: chunk, encoding: .utf8) else { return }
            s.split(separator: "\n").forEach { _ in onEvent() }
        }

        do {
            try proc.run()
        } catch {
            Log.line("glazewm sub failed to launch (\(binary)): \(error)")
            handle.readabilityHandler = nil
            return
        }
        proc.waitUntilExit()
        handle.readabilityHandler = nil
    }

    private func run(_ args: [String]) -> String? {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
        } catch {
            Log.line("glazewm \(args.joined(separator: " ")) failed to launch (\(binary)): \(error)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        return String(data: data, encoding: .utf8)
    }
}
