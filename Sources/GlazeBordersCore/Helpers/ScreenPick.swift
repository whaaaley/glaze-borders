import CoreGraphics

/// Pure screen-selection logic, separated from AppKit so it can be unit-tested.
///
/// The daemon must flip window geometry using the height/origin of the screen the
/// window actually lives on. Using the main screen unconditionally misplaces the
/// border vertically on a secondary display whose height differs from the main
/// one. Given the candidate screen frames (in AppKit coords) and the window's
/// frame (also AppKit coords), pick the screen the window overlaps most.
public enum ScreenPick {
    /// Choose the screen frame with the largest area of intersection with
    /// `windowFrame`. Falls back to the first frame when nothing overlaps (e.g. a
    /// window placed off every screen), and to `nil` when there are no screens.
    public static func best(for windowFrame: CGRect, among screens: [CGRect]) -> CGRect? {
        guard let first = screens.first else { return nil }
        var bestFrame = first
        var bestArea: CGFloat = -1
        for frame in screens {
            let overlap = frame.intersection(windowFrame)
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            if area > bestArea {
                bestArea = area
                bestFrame = frame
            }
        }
        return bestFrame
    }
}
