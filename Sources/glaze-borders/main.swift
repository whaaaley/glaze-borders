import AppKit
import GlazeBordersCore

// MARK: - Entry point
let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // no Dock icon, no menu bar

var cfg = Config()
let env = ProcessInfo.processInfo.environment
// GLAZE_BORDERS_POP=1 enables the native macOS appear "pop" on focus switch.
if env["GLAZE_BORDERS_POP"] == "1" { cfg.popOnFocus = true }
// Live-tunable geometry flags so we don't recompile while dialing them in.
if let r = env["GLAZE_BORDERS_RADIUS"], let v = Double(r) { cfg.cornerRadius = CGFloat(v) }
if let r = env["GLAZE_BORDERS_RADIUS_TOOLBAR"], let v = Double(r) { cfg.cornerRadiusToolbar = CGFloat(v) }
if let w = env["GLAZE_BORDERS_WIDTH"],  let v = Double(w) { cfg.width = CGFloat(v) }
if let o = env["GLAZE_BORDERS_OFFSET"], let v = Double(o) { cfg.offset = CGFloat(v) }

let daemon = Daemon(cfg: cfg, glaze: GlazeClient())
daemon.start()
app.run()
