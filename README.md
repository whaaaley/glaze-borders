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
- Benchmarks (`BenchmarkTests`, `LiveBenchmarkTests`, `E2ELatencyBenchmarkTests`) measure the hot paths and double as regression guards.

## Performance

End-to-end switch latency is the time from issuing a real GlazeWM focus command to the border redrawing on screen.

| Metric | Result |
|---|---|
| Switch → border redraw (median) | **~70 ms** (66–85 ms) |
| Pure decision path (geometry/radius/screen-pick) | sub-microsecond per call |
| AX focused-window read (incl. toolbar detection) | ~1 ms |

The border is event-driven: the focused window is parsed straight from the `glazewm sub` event payload, so a switch no longer spawns a `glazewm query windows` subprocess (~39 ms on this setup). That change cut switch latency from ~195 ms to ~70 ms.

Measured on:

- **MacBook Air (M2, Mac14,2)** — 8 cores, 16 GB
- **macOS 26.5** (Tahoe, build 25F71)
- Built-in Liquid Retina display, 2560×1664

## License

MIT
