A native macOS window-border daemon for GlazeWM, written in Swift on AppKit + the Accessibility API. Draws a single accent-colored border on the focused window.

## Layout

- `Sources/GlazeBordersCore/` — the library. Functional core (`Geometry`, `RadiusResolver`, `Reconciler`, pure, no AppKit) plus the imperative shell (`Daemon`, `Overlay`, `AXWatcher`, `GlazeClient`, `Classifier`).
- `Sources/glaze-borders/` — thin executable entry point that wires the library together.
- `Tests/GlazeBordersTests/` — swift-testing suites: unit, integration (live, environment-gated), and benchmarks.
- `tools/` — the conventional-commit validator (`CommitKit` Swift package) and its git hook.

## Build & test

- swift-testing and `llvm-cov` need the full Xcode toolchain, so the Makefile sets `DEVELOPER_DIR` to Xcode without changing the global `xcode-select`.
- Use the make tasks, not raw swift commands: `make build`, `make test`, `make coverage`, `make run`, `make install`. Run `make help` for the list.
- Integration and benchmark tests are gated on a live environment (GlazeWM running + Accessibility granted) and fail loudly with an actionable message when it is not satisfied.

## Conventions

- Do not include `Co-Authored-By` lines or any AI attribution in commit messages.
- Validate every commit message with the commit tool before committing, and never pass `--no-verify`.
- Coordinates: GlazeWM/AX use top-left origin (y-down); AppKit uses bottom-left (y-up). Convert once, in the geometry layer. Work in points and let AppKit handle Retina scaling — never multiply by the backing scale factor.

## Skills

@tools/SKILL.md
