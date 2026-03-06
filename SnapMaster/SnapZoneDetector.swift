import AppKit

class SnapZoneDetector {

    // MARK: - Detection

    /// Detects the snap zone for a point expressed in Core Graphics coordinates
    /// (top-left origin, Y increases downward).
    ///
    /// Returns `nil` when the point does not fall on any known screen.
    func detect(at cgPoint: CGPoint) -> (zone: SnapZone, screen: NSScreen)? {
        // Find the NSScreen whose CG-coordinate rect contains the point.
        guard let screen = screen(containing: cgPoint) else { return nil }

        let sr = cgRect(from: screen)   // screen rect in CG coords

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
    /// The primary screen's height is used as the total display height so that
    /// every screen can be mapped into a single CG coordinate space.
    private func cgRect(from nsScreen: NSScreen) -> CGRect {
        let primaryHeight = NSScreen.screens.first!.frame.height
        let nsFrame = nsScreen.frame
        return CGRect(
            x: nsFrame.origin.x,
            y: primaryHeight - nsFrame.origin.y - nsFrame.height,
            width: nsFrame.width,
            height: nsFrame.height
        )
    }

    /// Returns the `NSScreen` whose CG-coordinate frame contains `cgPoint`,
    /// or `nil` if no screen contains the point.
    private func screen(containing cgPoint: CGPoint) -> NSScreen? {
        return NSScreen.screens.first { screen in
            cgRect(from: screen).contains(cgPoint)
        }
    }
}
