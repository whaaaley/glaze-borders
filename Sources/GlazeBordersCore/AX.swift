import AppKit
import ApplicationServices

/// Accessibility-API access to the REAL on-screen geometry of windows, plus an
/// observer that fires when the focused window's frame changes.
///
/// Why: GlazeWM reports the frame it WANTS a window to have, but an app can
/// refuse to shrink below its minimum size (Chrome, Claude) or change size with
/// NO GlazeWM event at all (alt+f fullscreen). The border must follow the REAL
/// window, so we read geometry from AX and react to AX resize/move events.
///
/// AX frames are top-left origin / y-down — the SAME convention GlazeWM uses —
/// so the value drops straight into Overlay.update without extra conversion.
@MainActor
final class AXWatcher {
    /// Called whenever the watched window resizes/moves (debounce upstream).
    private let onChange: () -> Void
    private var observer: AXObserver?
    private var watchedPid: pid_t?
    private var watchedWindow: AXUIElement?

    init(onChange: @escaping () -> Void) { self.onChange = onChange }

    /// Real geometry + window-type info read from AX.
    struct WindowInfo {
        let frame: CGRect
        /// True if the window has a toolbar (Finder, System Settings, Mail, …).
        /// On Tahoe these use a LARGER corner radius than plain windows, so we
        /// use this to pick a matching radius. (No API reads the radius, but
        /// toolbar-presence is the signal that distinguishes the two classes.)
        let hasToolbar: Bool
    }

    /// Point the watcher at the focused window of `pid`. Re-attaches the AX
    /// observer if the window/pid changed. Returns the window's real frame and
    /// whether it has a toolbar.
    func watchFocusedWindow(pid: pid_t) -> WindowInfo? {
        let app = AXUIElementCreateApplication(pid)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &focused) == .success,
              let ref = focused, CFGetTypeID(ref) == AXUIElementGetTypeID()
        else { return nil }
        let window = ref as! AXUIElement

        // (Re)attach the observer if we're now watching a different window.
        if pid != watchedPid || !sameElement(window, watchedWindow) {
            detach()
            attach(pid: pid, window: window)
        }
        guard let f = frame(of: window) else { return nil }
        return WindowInfo(frame: f, hasToolbar: hasToolbar(window))
    }

    /// Does this window contain an AXToolbar child? (Tahoe toolbar windows.)
    private func hasToolbar(_ window: AXUIElement) -> Bool {
        var kids: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &kids) == .success,
              let children = kids as? [AXUIElement]
        else { return false }
        for child in children {
            var role: CFTypeRef?
            if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &role) == .success,
               (role as? String) == (kAXToolbarRole as String) {
                return true
            }
        }
        return false
    }

    /// Frame of an AX window element (top-left / y-down).
    func frame(of window: AXUIElement) -> CGRect? {
        guard let pos = axValue(window, kAXPositionAttribute, .cgPoint, CGPoint.self),
              let size = axValue(window, kAXSizeAttribute, .cgSize, CGSize.self)
        else { return nil }
        return CGRect(origin: pos, size: size)
    }

    func detach() {
        if let obs = observer, let win = watchedWindow {
            AXObserverRemoveNotification(obs, win, kAXResizedNotification as CFString)
            AXObserverRemoveNotification(obs, win, kAXMovedNotification as CFString)
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(),
                                  AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        observer = nil; watchedWindow = nil; watchedPid = nil
    }

    // MARK: - private

    private func attach(pid: pid_t, window: AXUIElement) {
        var obs: AXObserver?
        let cb: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let me = Unmanaged<AXWatcher>.fromOpaque(refcon).takeUnretainedValue()
            // Hop to main actor; AXObserver fires on the run loop we registered.
            MainActor.assumeIsolated { me.onChange() }
        }
        guard AXObserverCreate(pid, cb, &obs) == .success, let obs else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(obs, window, kAXResizedNotification as CFString, refcon)
        AXObserverAddNotification(obs, window, kAXMovedNotification as CFString, refcon)
        CFRunLoopAddSource(CFRunLoopGetCurrent(),
                           AXObserverGetRunLoopSource(obs), .defaultMode)

        observer = obs; watchedWindow = window; watchedPid = pid
    }

    private func sameElement(_ a: AXUIElement, _ b: AXUIElement?) -> Bool {
        guard let b else { return false }
        return CFEqual(a, b)
    }

    private func axValue<T>(_ el: AXUIElement, _ attr: String,
                            _ kind: AXValueType, _ type: T.Type) -> T? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success,
              let value = ref, CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        let out = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { out.deallocate() }
        guard AXValueGetValue(value as! AXValue, kind, out) else { return nil }
        return out.pointee
    }
}
