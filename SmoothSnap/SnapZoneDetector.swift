import AppKit

class SnapZoneDetector {

    // MARK: - Detection

    /// Detects the snap zone for a point expressed in Core Graphics coordinates
    /// (top-left origin, Y increases downward).
    ///
    /// Returns `nil` only when `NSScreen.screens` is empty (no display attached).
    func detect(at cgPoint: CGPoint) -> (zone: SnapZone, screen: NSScreen)? {
        // Use nearestScreen so we always have a screen context, but only
        // detect snap zones when the cursor is actually on a screen.
        // Returning (.none, screen) for gap positions avoids false triggers
        // when the cursor sits exactly on a clamped screen boundary.
        guard let screen = nearestScreen(to: cgPoint) else { return nil }

        let sr = cgRect(from: screen)   // screen rect in CG coords

        // Don't trigger snap zones when the cursor is in a gap between monitors.
        guard sr.contains(cgPoint) else { return (.none, screen) }

        // Read live values from AppSettings so that changes in Preferences
        // are reflected immediately without restarting the app.
        let edge   = AppSettings.shared.edgeThreshold
        let corner = AppSettings.shared.cornerThreshold

        let nearLeft   = cgPoint.x - sr.minX <= edge
        let nearRight  = sr.maxX - cgPoint.x <= edge
        let nearTop    = cgPoint.y - sr.minY <= edge      // CG: minY is the top
        let nearBottom = sr.maxY - cgPoint.y <= edge      // CG: maxY is the bottom

        let inCornerV  = cgPoint.y - sr.minY <= corner    // near top corner band (CG)

        // --- Corner zones have priority over pure edge zones ---

        // Top-left corner
        if nearLeft && inCornerV {
            return (.topLeft, screen)
        }

        // Top-right corner
        if nearRight && inCornerV {
            return (.topRight, screen)
        }

        let inCornerVB = sr.maxY - cgPoint.y <= corner    // near bottom corner band (CG)

        // Bottom-left corner
        if nearLeft && inCornerVB {
            return (.bottomLeft, screen)
        }

        // Bottom-right corner
        if nearRight && inCornerVB {
            return (.bottomRight, screen)
        }

        // --- Pure edge zones ---

        // Top edge — full-width maximize
        if nearTop {
            return (.top, screen)
        }

        // Bottom edge — thirds and bottom-half zones are resolved by X position.
        //
        // The bottom edge is divided into five logical bands using two thresholds:
        //
        //   │← 1/4 →│←  1/4  →│←  1/4  →│←  1/4  →│
        //   │← 1/3      →│←  1/3      →│←  1/3      →│
        //
        //   X < 1/4        → leftThird   (clearly left-biased)
        //   1/4 ≤ X < 1/3  → bottom      (inside centre ¼–¾ band, not the exact third)
        //   1/3 ≤ X < 2/3  → centerThird (takes priority per spec)
        //   2/3 ≤ X < 3/4  → bottom      (inside centre ¼–¾ band, not the exact third)
        //   X ≥ 3/4        → rightThird  (clearly right-biased)
        //
        // Corner bands (!nearLeft, !nearRight) are already handled above.
        if nearBottom && !nearLeft && !nearRight {
            let relativeX = cgPoint.x - sr.minX
            let oneQuarter = sr.width / 4
            let oneThird   = sr.width / 3
            let twoThirds  = sr.width * 2 / 3
            let threeQ     = sr.width * 3 / 4

            if relativeX < oneQuarter {
                return (.leftThird, screen)
            } else if relativeX < oneThird {
                return (.bottom, screen)
            } else if relativeX < twoThirds {
                return (.centerThird, screen)
            } else if relativeX < threeQ {
                return (.bottom, screen)
            } else {
                return (.rightThird, screen)
            }
        }

        // Left edge — corner cases already handled above
        if nearLeft {
            return (.left, screen)
        }

        // Right edge — corner cases already handled above
        if nearRight {
            return (.right, screen)
        }

        return (.none, screen)
    }

    // MARK: - Private Helpers

    /// Converts an `NSScreen.frame` (AppKit, bottom-left origin) to a `CGRect`
    /// in Core Graphics coordinates (top-left origin, Y increases downward).
    ///
    /// macOS maps all screens into a single CG coordinate space using the
    /// primary screen's total height as the reference. The primary screen is
    /// always `NSScreen.screens[0]`; every other screen is offset relative to it.
    ///
    /// Returns `nil` when no screens are available (headless / no display).
    private func cgRect(from nsScreen: NSScreen) -> CGRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else {
            // Fallback: treat the screen's own frame as if it were the primary.
            // This branch is reached only in edge cases (e.g. display hot-unplug
            // occurring between the caller obtaining nsScreen and this call).
            let f = nsScreen.frame
            return CGRect(x: f.origin.x, y: 0, width: f.width, height: f.height)
        }
        let nsFrame = nsScreen.frame
        return CGRect(
            x: nsFrame.origin.x,
            y: primaryHeight - nsFrame.origin.y - nsFrame.height,
            width: nsFrame.width,
            height: nsFrame.height
        )
    }

    /// Returns the `NSScreen` whose CG-coordinate frame contains `cgPoint`.
    ///
    /// If no screen directly contains the point (e.g. the cursor is in a gap
    /// between two monitors), returns the screen whose frame is closest to the
    /// point measured by minimum edge distance. This prevents snap detection
    /// from dropping out when the cursor moves quickly across a monitor boundary.
    private func nearestScreen(to cgPoint: CGPoint) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else { return nil }

        // Fast path: the point is inside one of the screen rects.
        if let exact = screens.first(where: { cgRect(from: $0).contains(cgPoint) }) {
            return exact
        }

        // Slow path: find the screen with the smallest squared distance from
        // cgPoint to the nearest point on its CG-coordinate rect.
        return screens.min { a, b in
            cgRect(from: a).squaredDistance(to: cgPoint) <
            cgRect(from: b).squaredDistance(to: cgPoint)
        }
    }
}

// MARK: - CGRect nearest-point helper

private extension CGRect {
    /// Returns the squared Euclidean distance from `point` to the nearest point
    /// on (or inside) this rect.  Zero when `point` is already inside.
    func squaredDistance(to point: CGPoint) -> CGFloat {
        let dx = max(minX - point.x, 0, point.x - maxX)
        let dy = max(minY - point.y, 0, point.y - maxY)
        return dx * dx + dy * dy
    }
}
