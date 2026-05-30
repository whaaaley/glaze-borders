import AppKit
import GlazeBordersCore

// MARK: - Entry point
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar

var cfg = Config()
let env = ProcessInfo.processInfo.environment
// GLAZE_BORDERS_POP=1 enables the native macOS appear "pop" on focus switch.
if EnvParse.flag(env, "GLAZE_BORDERS_POP") { cfg.popOnFocus = true }
// Live-tunable geometry flags so we don't recompile while dialing them in.
if let v = EnvParse.cgFloat(env, "GLAZE_BORDERS_RADIUS")         { cfg.cornerRadius = v }
if let v = EnvParse.cgFloat(env, "GLAZE_BORDERS_RADIUS_TOOLBAR") { cfg.cornerRadiusToolbar = v }
if let v = EnvParse.cgFloat(env, "GLAZE_BORDERS_WIDTH")          { cfg.width = v }
if let v = EnvParse.cgFloat(env, "GLAZE_BORDERS_OFFSET")         { cfg.offset = v }

let daemon = Daemon(cfg: cfg, glaze: GlazeClient())
daemon.start()
app.run()
