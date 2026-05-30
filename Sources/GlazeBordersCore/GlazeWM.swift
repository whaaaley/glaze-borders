import Foundation

// MARK: - GlazeWM data model
//
// We only decode the fields we actually use. GlazeWM reports window frames in a
// TOP-LEFT origin, y-DOWN coordinate space (y=47 is just below the menu bar).
// AppKit is bottom-left / y-up — the conversion happens in Overlay, not here.

/// A window as reported by `glazewm query windows`.
public struct GlazeWindow: Decodable, Equatable, Sendable {
    public let id: String
    public let processName: String
    public let hasFocus: Bool
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let state: State
    public let displayState: String

    public struct State: Decodable, Equatable, Sendable {
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

/// Accumulates raw pipe bytes and yields complete newline-terminated lines.
/// `FileHandle.readabilityHandler` invocations are serialized, so the unguarded
/// mutable buffer is safe; `@unchecked Sendable` documents that we rely on it.
private final class LineBuffer: @unchecked Sendable {
    private var pending = Data()

    /// Append a chunk and return any complete lines it completes (without the
    /// trailing newline). A partial final line is kept for the next chunk.
    func append(_ chunk: Data) -> [String] {
        pending.append(chunk)
        var lines: [String] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            let lineData = pending[pending.startIndex..<nl]
            if !lineData.isEmpty, let s = String(data: lineData, encoding: .utf8) {
                lines.append(s)
            }
            pending.removeSubrange(pending.startIndex...nl)
        }
        return lines
    }
}

/// Envelope shared by every glazewm IPC response: `{ data, error, success }`.
private struct Envelope<T: Decodable>: Decodable {
    let data: T
    let success: Bool
    let error: String?
}

private struct WindowsQuery: Decodable { let windows: [GlazeWindow] }

/// One `glazewm sub` event line. Many event types carry the focused container
/// inline (`focusedContainer`), which lets us skip a separate `query windows`
/// for the common focus-change case. A container can be a window OR a workspace;
/// we only care when it's a window, so geometry fields are optional.
struct SubEvent: Decodable {
    let data: EventData
    struct EventData: Decodable {
        let eventType: String
        let focusedContainer: FocusedContainer?
    }
    /// The focused container. Decodes leniently: workspaces lack window fields.
    struct FocusedContainer: Decodable {
        let type: String
        let id: String
        let hasFocus: Bool?
        let x: Int?
        let y: Int?
        let width: Int?
        let height: Int?
        let state: GlazeWindow.State?
        let displayState: String?

        /// Promote to a full GlazeWindow when this container is a window with
        /// complete geometry; nil for workspaces or partial payloads.
        var asWindow: GlazeWindow? {
            guard type == "window",
                  let x, let y, let width, let height,
                  let state, let displayState else { return nil }
            return GlazeWindow(id: id, processName: "", hasFocus: hasFocus ?? true,
                               x: x, y: y, width: width, height: height,
                               state: state, displayState: displayState)
        }
    }
}

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

    /// Spawns `glazewm sub` and calls `onEvent` for every event line received,
    /// passing the focused window parsed straight from the event payload (or nil
    /// when the event carries no focused window). Parsing the payload avoids a
    /// separate ~75ms `query windows` per event — the dominant switch-latency
    /// cost. Blocks the calling thread; run on a background queue. Returns when
    /// the subprocess exits (caller is expected to restart it).
    func subscribe(events: [String], onEvent: @escaping @Sendable (GlazeWindow?) -> Void) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = ["sub", "--events"] + events
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice

        // `glazewm sub` emits one JSON object per line, but a read may split a
        // line across chunks — buffer until we see a newline before decoding.
        let buffer = LineBuffer()
        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { fh in
            let chunk = fh.availableData
            guard !chunk.isEmpty else { return }
            for line in buffer.append(chunk) {
                guard let data = line.data(using: .utf8) else { onEvent(nil); continue }
                let event = try? JSONDecoder().decode(SubEvent.self, from: data)
                onEvent(event?.data.focusedContainer?.asWindow)
            }
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
