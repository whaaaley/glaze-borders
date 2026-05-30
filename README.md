# glaze-borders

A native macOS window-border daemon for [GlazeWM](https://github.com/glzr-io/glazewm) — *if Apple made borders.*

It draws a single, crisp accent-colored border around the focused window, with corner radii that match macOS Tahoe's own windows. Built in Swift on AppKit + the Accessibility API, with no private frameworks and no hidpi hacks.

## Why

JankyBorders is the usual choice, but on macOS Tahoe (26) it has a hidpi corner-offset bug, high GPU usage, and doesn't follow GlazeWM's window moves reliably. `glaze-borders` is a from-scratch replacement that:

- **Draws in points, not pixels** — AppKit handles Retina scaling, so borders never land offset (the JankyBorders hidpi bug).
- **Reads real geometry from the Accessibility API** — GlazeWM reports the frame it *wants*; apps with a minimum size (Chrome, Slack) overflow their tile. The border follows the *actual* window.
- **Follows fullscreen and resize** via an AX observer plus a low-frequency safety poll — even when GlazeWM emits no event (e.g. `alt+f`).
- **Matches Tahoe's per-type corner radii** — toolbar windows (Finder, System Settings) are rounder than plain windows (terminals, editors); classification is detected via AX and cached persistently.
- **Uses your system accent color** — resolved live, so it tracks Appearance changes.
- **Snappy** — a single pooled overlay window, no implicit animations, instant focus follow.

## Architecture

Functional core, imperative shell:

- **Pure core** (`Geometry`, `RadiusResolver`, `Reconciler`) — no AppKit/AX, fully unit-testable. Given a snapshot of the world, decides what to draw.
- **Imperative shell** (`Daemon`, `Overlay`, `AXWatcher`, `GlazeClient`) — gathers inputs (GlazeWM IPC, AX reads, screen) and applies the decision to AppKit.
- **Persistent classification** (`Classifier`) — one-way sticky toolbar/plain cache at `~/.config/glaze-borders/classifications.json`.

## Build & run

```sh
swift build -c release
.build/release/glaze-borders
```

Install as a login agent (auto-start):

```sh
cp .build/release/glaze-borders ~/.local/bin/glaze-borders
# load the LaunchAgent (see contrib/com.dustin.glaze-borders.plist)
```

Requires Accessibility permission (System Settings → Privacy & Security → Accessibility).

## Configuration

Defaults are baked in; these env vars override them for live tuning:

| Variable | Meaning | Default |
|---|---|---|
| `GLAZE_BORDERS_WIDTH` | stroke width (pt) | 2 |
| `GLAZE_BORDERS_OFFSET` | 0 = inner; negative pushes outward | 0 |
| `GLAZE_BORDERS_RADIUS` | plain-window corner radius | 10 |
| `GLAZE_BORDERS_RADIUS_TOOLBAR` | toolbar-window corner radius | 22 |
| `GLAZE_BORDERS_POP` | `1` = native appear "pop" on focus | off |
| `GLAZE_BORDERS_DEBUG` | `1` = log to `/tmp/glaze-borders.debug.log` | off |

## Tests

```sh
swift test
```

Unit tests cover the pure geometry/radius logic with input→output tables; integration tests cover the reconciler decision and classifier persistence.

## License

MIT
