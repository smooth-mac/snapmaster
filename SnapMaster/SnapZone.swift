import AppKit

// Coordinate system notes:
// - NSScreen.frame / visibleFrame: bottom-left origin, Y up (AppKit)
// - CGPoint from CGEvent: top-left origin, Y down (Core Graphics)
// - AXUIElement position: top-left origin, Y down (same as CG)
// - We work in AppKit NSRect internally; WindowController handles CG conversion

enum SnapZone: String, CaseIterable, Equatable, Codable {
    case left
    case right
    case top
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftThird
    case centerThird
    case rightThird
    case bottom
    case none

    // MARK: - State

    var isActive: Bool {
        return self != .none
    }

    // MARK: - Display Name

    var displayName: String {
        switch self {
        case .left:        return "Left Half"
        case .right:       return "Right Half"
        case .top:         return "Maximize"
        case .topLeft:     return "Top Left"
        case .topRight:    return "Top Right"
        case .bottomLeft:  return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        case .leftThird:   return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird:  return "Right Third"
        case .bottom:      return "Bottom Half"
        case .none:        return "None"
        }
    }

    // MARK: - Target Frame

    /// Returns the target NSRect in AppKit coordinates (bottom-left origin).
    /// Uses screen.visibleFrame, which excludes the menu bar and Dock.
    func targetFrame(screen: NSScreen) -> NSRect {
        let vf = screen.visibleFrame

        let halfW  = (vf.width / 2).rounded()
        let halfH  = (vf.height / 2).rounded()
        let thirdW = (vf.width / 3).rounded()

        switch self {
        case .left:
            return NSRect(x: vf.minX, y: vf.minY, width: halfW, height: vf.height)

        case .right:
            return NSRect(x: vf.minX + halfW, y: vf.minY, width: vf.width - halfW, height: vf.height)

        case .top:
            // Full maximize — fill the entire visible frame
            return vf

        case .topLeft:
            return NSRect(x: vf.minX, y: vf.minY + halfH, width: halfW, height: vf.height - halfH)

        case .topRight:
            return NSRect(x: vf.minX + halfW, y: vf.minY + halfH, width: vf.width - halfW, height: vf.height - halfH)

        case .bottomLeft:
            return NSRect(x: vf.minX, y: vf.minY, width: halfW, height: halfH)

        case .bottomRight:
            return NSRect(x: vf.minX + halfW, y: vf.minY, width: vf.width - halfW, height: halfH)

        case .leftThird:
            return NSRect(x: vf.minX, y: vf.minY, width: thirdW, height: vf.height)

        case .centerThird:
            return NSRect(x: vf.minX + thirdW, y: vf.minY, width: thirdW, height: vf.height)

        case .rightThird:
            // Use remaining width to avoid sub-pixel gaps caused by rounding.
            return NSRect(x: vf.minX + thirdW * 2, y: vf.minY, width: vf.width - thirdW * 2, height: vf.height)

        case .bottom:
            // Full-width bottom half — symmetric counterpart of .top (maximize).
            return NSRect(x: vf.minX, y: vf.minY, width: vf.width, height: halfH)

        case .none:
            return .zero
        }
    }

    // MARK: - Preview Color

    /// A distinct, semi-transparent color used for the drag-preview overlay.
    var previewColor: NSColor {
        switch self {
        // Blue family — halves & corners
        case .left:
            return NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.95, alpha: 0.35)

        case .right:
            return NSColor(calibratedRed: 0.10, green: 0.40, blue: 0.90, alpha: 0.35)

        case .top:
            return NSColor(calibratedRed: 0.00, green: 0.60, blue: 1.00, alpha: 0.30)

        case .topLeft:
            return NSColor(calibratedRed: 0.25, green: 0.55, blue: 0.85, alpha: 0.38)

        case .topRight:
            return NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.88, alpha: 0.38)

        case .bottomLeft:
            return NSColor(calibratedRed: 0.30, green: 0.60, blue: 0.80, alpha: 0.38)

        case .bottomRight:
            return NSColor(calibratedRed: 0.20, green: 0.50, blue: 0.78, alpha: 0.38)

        // Green family — thirds
        case .leftThird:
            return NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.35, alpha: 0.35)

        case .centerThird:
            return NSColor(calibratedRed: 0.05, green: 0.65, blue: 0.28, alpha: 0.35)

        case .rightThird:
            return NSColor(calibratedRed: 0.00, green: 0.58, blue: 0.22, alpha: 0.35)

        // Purple — bottom half (symmetric counterpart of .top)
        case .bottom:
            return NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.90, alpha: 0.32)

        case .none:
            return NSColor.clear
        }
    }
}
