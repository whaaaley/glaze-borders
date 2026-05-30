import AppKit
// MARK: - Config (matches the old bordersrc)
public struct Config {
    public init() {}
    public var width: CGFloat = 2.0
    // Tahoe uses different window corner radii by type. No API reads the real
    // value, but toolbar-presence (AX) distinguishes the two classes:
    //   plain windows (terminals, editors) -> smaller radius
    //   toolbar windows (Finder, System Settings, Mail) -> larger radius
    public var cornerRadius: CGFloat = 10.0        // plain windows (terminals, editors)
    public var cornerRadiusToolbar: CGFloat = 22.0 // toolbar windows (Finder, System Settings)
    // Per-app radius overrides for windows that fit neither class (e.g. panels
    // like "About This Mac" / System Information — rounder than plain, less than
    // a toolbar window). Keyed by GlazeWM processName.
    public var radiusOverrides: [String: CGFloat] = [
        "System Information": 14,
    ]
    // How far the border sits from the window edge (INNER by default).
    //   offset = 0  -> pure INNER (whole stroke inside the window edge)
    //   offset < 0  -> pushed OUTWARD past the window edge by |offset| points
    public var offset: CGFloat = 0.0
    // Events that change geometry or focus -> trigger a reconcile.
    public var events = [
        "focus_changed", "focused_container_moved",
        "window_managed", "window_unmanaged",
        "workspace_activated", "workspace_updated",
        "tiling_direction_changed", "monitor_updated",
    ]
    // Coalesce bursts: wait this long after the last nudge before reconciling.
    // Kept small so a focus switch (a near-single event) redraws promptly; it
    // still collapses the rapid multi-event bursts that a close/move produces.
    public var settle: TimeInterval = 0.016

    // When true, the border gets the default macOS window-appear "pop" each time
    // it lands on a newly-focused window (we recreate the overlay window). When
    // false, a single overlay is reused and just moves instantly (snappy). One
    // flag, no custom animation — just on/off for the native pop.
    public var popOnFocus = false

    /// The subset the pure Reconciler needs (keeps it free of AppKit Config).
    var reconcilerSettings: Reconciler.Settings {
        .init(width: width, offset: offset,
              cornerRadius: cornerRadius, cornerRadiusToolbar: cornerRadiusToolbar,
              radiusOverrides: radiusOverrides)
    }
}

/// Owns the overlay windows and reconciles them against GlazeWM state.
/// All overlay/AppKit work happens on the main thread, hence @MainActor.
@MainActor
public final class Daemon {
    private let cfg: Config
    private let glaze: WindowSource
    private var reconcileScheduled = false
    private var ax: AXWatcher!

    // We only ever border ONE window (the focused one), so we track a single
    // overlay plus which window id it currently wraps.
    private var overlay: Overlay?
    private var lastPlacement: Geometry.Placement?  // last placement painted; skip redundant redraws
    private var lastRadius: CGFloat? // last radius we painted; redraw if it changes
    // The most recent focused window, parsed from a GlazeWM event payload. Events
    // that carry no focused window (and the poll/AX observer) reconcile against
    // this last-known value instead of re-querying.
    private var latestFocused: GlazeWindow?
    // Persistent, one-way window-type classification keyed by app name. Prevents
    // radius flicker from transient AX misses and survives restarts.
    private let classifier = Classifier()
    private var overlayWindowId: String?

    public init(cfg: Config, glaze: WindowSource) {
        self.cfg = cfg
        self.glaze = glaze
        // The AX observer fires whenever the focused window resizes/moves — even
        // when GlazeWM emits no event (e.g. alt+f fullscreen). It carries no new
        // GlazeWM window, so it reconciles against the last known one.
        self.ax = AXWatcher(onChange: { [weak self] in self?.scheduleReconcile(focused: self?.latestFocused) })
    }

    /// Coalesced entry point: many events collapse into one reconcile. `focused`
    /// is the focused window parsed from the GlazeWM event payload (nil for the
    /// safety poll / AX observer, which reuse the last known focused window).
    func scheduleReconcile(focused: GlazeWindow?) {
        if let focused { latestFocused = focused }
        guard !reconcileScheduled else { return }
        reconcileScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + cfg.settle) { [weak self] in
            self?.reconcileScheduled = false
            self?.reconcile()
        }
    }

    /// Border the FOCUSED window only; unfocused windows get no border. Uses the
    /// focused window from the GlazeWM event (no per-event `query windows`), with
    /// its real frame read from AX. Internal (not private) so tests can drive a
    /// single reconcile synchronously without the debounce/timer machinery.
    func reconcile() {
        // The focused window comes from the latest event payload, not a query.
        // The safety poll falls back to a one-off query when we have nothing yet.
        let windows: [GlazeWindow]
        if let focused = latestFocused {
            windows = [focused]
        } else {
            // Only before the first GlazeWM event lands (startup). Seed the cache
            // so steady-state never re-queries.
            windows = glaze.queryWindows()
            latestFocused = windows.first { $0.isBordered && $0.hasFocus }
        }

        // The window we actually border is the FRONTMOST app's window (which may
        // differ from GlazeWM's focus for floating windows like About This Mac).
        var front: Reconciler.Input.Front?
        if let app = NSWorkspace.shared.frontmostApplication,
           let info = ax.watchFocusedWindow(pid: app.processIdentifier) {
            let appName = app.localizedName ?? ""
            // Persist the toolbar/plain class (one-way, sticky) before deciding.
            classifier.observe(appName, hasToolbar: info.hasToolbar)
            front = .init(app: appName, frame: info.frame, hasToolbar: info.hasToolbar)
        }

        let input = Reconciler.Input(
            windows: windows,
            front: front,
            screenFrame: screenFrame(for: front?.frame))

        // --- Pure core: decide what to draw (fully tested in isolation) ---
        let command = Reconciler.decide(
            input,
            config: cfg.reconcilerSettings,
            classify: { [classifier] in classifier.known($0) })

        // --- Imperative shell: apply the decision ---
        guard let command else {
            hideOverlay()
            Log.line("reconcile: focused=none")
            return
        }

        let focusChanged = overlayWindowId != command.windowId
        if cfg.popOnFocus && focusChanged { hideOverlay() }

        let activeOverlay: Overlay
        if let existing = overlay {
            activeOverlay = existing
        } else {
            activeOverlay = Overlay(width: cfg.width)
            overlay = activeOverlay
        }
        overlayWindowId = command.windowId

        // Skip the redraw if nothing changed (the safety poll calls us often).
        if command.placement == lastPlacement && command.cornerRadius == lastRadius && !focusChanged { return }
        lastPlacement = command.placement
        lastRadius = command.cornerRadius

        // Accent color resolved live (tracks the user's Appearance setting).
        activeOverlay.apply(placement: command.placement,
                            color: .controlAccentColor,
                            cornerRadius: command.cornerRadius)
        Log.line("reconcile: window=\(command.windowId) radius=\(command.cornerRadius)")
    }

    /// The AppKit frame of the screen a window lives on, for the y-flip. Using the
    /// main screen unconditionally misplaces the border on a secondary display of
    /// a different height, so we pick the screen the window overlaps most.
    ///
    /// `windowFrame` is in AX/CG global coords (top-left origin). AppKit's global
    /// space is bottom-left with the PRIMARY screen as the reference, so we flip
    /// against the primary screen height before intersecting with screen frames.
    private func screenFrame(for windowFrame: CGRect?) -> CGRect? {
        let screens = NSScreen.screens.map(\.frame)
        guard let windowFrame else { return screens.first }
        // Primary screen is the one whose AppKit origin is (0, 0).
        let primaryHeight = screens.first(where: { $0.origin == .zero })?.height
            ?? screens.first?.height ?? windowFrame.height
        let appKitFrame = CGRect(
            x: windowFrame.origin.x,
            y: primaryHeight - windowFrame.origin.y - windowFrame.height,
            width: windowFrame.width, height: windowFrame.height)
        return ScreenPick.best(for: appKitFrame, among: screens)
    }

    /// Tear down the current overlay (if any) and forget which window it wrapped.
    private func hideOverlay() {
        guard let ov = overlay else { return }
        ov.hide()
        overlay = nil
        overlayWindowId = nil
        lastPlacement = nil
        lastRadius = nil
    }

    /// Start the two input streams: GlazeWM events (authoritative) and macOS
    /// window open/close (catches anything GlazeWM is slow to report).
    public func start() {
        reconcile()  // initial paint

        // 1. GlazeWM event stream on a background thread; restart if it dies.
        //    `glaze` and `events` are captured as values so we don't send the
        //    main-actor `self` into the background closure.
        let glaze = self.glaze
        let events = self.cfg.events
        // Each event delivers the focused window parsed from its payload (or nil);
        // we forward it so reconcile draws without a per-event query.
        let onEvent: @Sendable (GlazeWindow?) -> Void = { [weak self] focused in
            DispatchQueue.main.async { self?.scheduleReconcile(focused: focused) }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            // Back off on repeated immediate exits so a missing/broken `glazewm`
            // can't spin a silent hot-loop; reset once a subscription lasts a while.
            var backoff: TimeInterval = 1.0
            while true {
                glaze.subscribe(events: events, onEvent: onEvent)
                Log.line("glazewm sub exited; retrying in \(backoff)s")
                Thread.sleep(forTimeInterval: backoff)
                backoff = min(backoff * 2, 30.0)
            }
        }

        // 2. macOS window lifecycle: app launches/terminations and window
        //    open/close surface as workspace notifications. These are a safety
        //    net so we react even when a GlazeWM event is missing or late.
        let nc = NSWorkspace.shared.notificationCenter
        for name: NSNotification.Name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // queue: .main delivers on the main thread, but the closure is
                // nonisolated; assumeIsolated makes the main-actor hop explicit.
                MainActor.assumeIsolated { self?.scheduleReconcile(focused: nil) }
            }
        }

        // 3. Slow safety poll. Some geometry changes (notably alt+f fullscreen)
        //    fire NO GlazeWM event AND no AX notification we can catch reliably,
        //    so the event-driven paths can miss them. A low-frequency poll
        //    guarantees the border never stays stale for long. Cheap: one
        //    query + one AX read every tick, and reconcile() no-ops if nothing
        //    actually changed (it just redraws the same frame).
        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reconcile() }
        }
        // Add explicitly in .common mode so it keeps firing during run-loop
        // tracking (and isn't lost depending on when start() runs vs app.run()).
        RunLoop.main.add(timer, forMode: .common)
    }
}
