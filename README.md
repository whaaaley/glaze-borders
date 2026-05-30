# glaze-borders

A native macOS window-border daemon for [GlazeWM](https://github.com/glzr-io/glazewm). It draws a single accent-colored border around the focused window, built in Swift on AppKit and the Accessibility API — no private frameworks.

## Features

- **Focused-window only** — one border, your system accent color, resolved live so it tracks Appearance changes.
- **Pixel-accurate** — draws in points and lets AppKit handle Retina scaling, so borders never land offset.
- **Real geometry** — reads the actual window frame from the Accessibility API, so windows with a minimum size (Chrome, Slack) that overflow their tile still get a correct border.
- **Follows everything** — focus changes, moves, resizes, and fullscreen (`alt+f`), via an AX observer plus a low-frequency safety poll.
- **Tahoe-matched corners** — toolbar windows (Finder, System Settings) use a larger radius than plain windows (terminals, editors); the class is detected via AX and cached.
- **Snappy** — a single reused overlay window, no animations, instant focus follow.

## Install

```sh
swift build -c release
cp .build/release/glaze-borders ~/.local/bin/glaze-borders
```

- Run directly: `glaze-borders`
- Auto-start at login: load the LaunchAgent in `contrib/com.dustin.glaze-borders.plist`
- Grant Accessibility permission: System Settings → Privacy & Security → Accessibility

## Configuration

Defaults are baked in. Override any of these with environment variables:

| Variable | Meaning | Default |
|---|---|---|
| `GLAZE_BORDERS_WIDTH` | stroke width (pt) | 2 |
| `GLAZE_BORDERS_OFFSET` | 0 = inner; negative pushes outward | 0 |
| `GLAZE_BORDERS_RADIUS` | plain-window corner radius | 10 |
| `GLAZE_BORDERS_RADIUS_TOOLBAR` | toolbar-window corner radius | 22 |
| `GLAZE_BORDERS_POP` | `1` = native appear animation on focus | off |
| `GLAZE_BORDERS_DEBUG` | `1` = log to `/tmp/glaze-borders.debug.log` | off |

## Architecture

Functional core, imperative shell:

- **Pure core** — `Geometry`, `RadiusResolver`, `Reconciler`. No AppKit or AX; given a snapshot of the world, decides what to draw. Fully unit-testable.
- **Imperative shell** — `Daemon`, `Overlay`, `AXWatcher`, `GlazeClient`. Gathers inputs (GlazeWM IPC, AX reads, screen) and applies the decision to AppKit.
- **Persistent classification** — `Classifier`. One-way sticky toolbar/plain cache at `~/.config/glaze-borders/classifications.json`.

## Tests

```sh
swift test
```

- Unit tests cover the pure geometry and radius logic with input/output tables.
- Integration tests cover the reconciler decision and classifier persistence.

## License

MIT
