import AppKit

class WindowController {

    // MARK: - Primary Screen Height

    private static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    // MARK: - Get Frontmost Window

    /// Get the focused window of the frontmost application.
    /// Returns nil if no window is focused or accessibility is not granted.
    static func getFrontmostWindow() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(pid)

        var windowRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef)

        guard result == .success, let windowRef = windowRef else {
            return nil
        }

        return (windowRef as! AXUIElement)
    }

    // MARK: - Get Frame

    /// Get the current frame of a window in AppKit coordinates (bottom-left origin).
    static func getFrame(of window: AXUIElement) -> NSRect? {
        // Read position
        var positionRef: CFTypeRef?
        let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionRef)
        guard posResult == .success, let positionRef = positionRef else {
            return nil
        }

        var point = CGPoint.zero
        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &point) else {
            return nil
        }

        // Read size
        var sizeRef: CFTypeRef?
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)
        guard sizeResult == .success, let sizeRef = sizeRef else {
            return nil
        }

        var size = CGSize.zero
        guard AXValueGetValue(sizeRef as! AXValue, .cgSize, &size) else {
            return nil
        }

        // Convert from CG coordinates (top-left origin) to NS coordinates (bottom-left origin)
        let nsY = primaryHeight - point.y - size.height

        return NSRect(x: point.x, y: nsY, width: size.width, height: size.height)
    }

    // MARK: - Set Frame

    /// Set the frame of a window using AppKit coordinates (bottom-left origin).
    /// Internally converts to CG coordinates for AXUIElement.
    /// Position is applied first, then size, as required by the Accessibility API.
    static func setFrame(_ frame: NSRect, for window: AXUIElement) {
        // Convert NS coordinates (bottom-left origin) to CG coordinates (top-left origin)
        let cgY = primaryHeight - frame.maxY
        var cgPoint = CGPoint(x: frame.origin.x, y: cgY)
        var cgSize = CGSize(width: frame.width, height: frame.height)

        // Create AXValue for position
        guard let posValue = AXValueCreate(.cgPoint, &cgPoint) else {
            return
        }

        // Create AXValue for size
        guard let sizeValue = AXValueCreate(.cgSize, &cgSize) else {
            return
        }

        // Apply position first (required order for AX API)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)

        // Small delay for reliability before applying size
        Thread.sleep(forTimeInterval: 0.01)

        // Apply size second
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
    }

    // MARK: - Accessibility Permission

    /// Returns true if Accessibility permission has been granted for this process.
    static var isAccessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission. Shows the system prompt if not already granted.
    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
