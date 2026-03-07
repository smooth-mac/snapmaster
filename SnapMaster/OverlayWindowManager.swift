import AppKit

// MARK: - OverlayView

/// A borderless NSView that draws a rounded-rectangle snap preview.
/// Fill and stroke colors are derived from the current SnapZone's previewColor.
private final class OverlayView: NSView {

    // MARK: Properties

    var zone: SnapZone = .none {
        didSet { needsDisplay = true }
    }

    // MARK: Configuration

    private let cornerRadius: CGFloat = 12
    private let borderWidth: CGFloat  = 2

    // MARK: NSView

    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let base        = zone.previewColor
        let fillColor   = base
        let strokeColor = base.withAlphaComponent(min(base.alphaComponent * 2.0, 0.9))

        let path = NSBezierPath(
            roundedRect: bounds,
            xRadius: cornerRadius,
            yRadius: cornerRadius
        )

        fillColor.setFill()
        path.fill()

        path.lineWidth = borderWidth
        strokeColor.setStroke()
        path.stroke()
    }
}

// MARK: - OverlayWindowManager

/// Manages a single floating, non-activating overlay window that shows a
/// semi-transparent snap-zone preview while the user is dragging a window.
///
/// Coordinate system: all public APIs accept AppKit NSRects (bottom-left origin).
final class OverlayWindowManager {

    // MARK: Private State

    private var overlayWindow: NSWindow?
    private var currentZone: SnapZone = .none
    private var currentScreen: NSScreen?

    // MARK: Public Interface

    /// Show the overlay at the position corresponding to `zone` on `screen`.
    ///
    /// - If `zone` is `.none` or equals the zone already being shown, the
    ///   overlay is hidden (toggle-off behaviour).
    /// - `screen` must be one of the screens in `NSScreen.screens`.
    func show(zone: SnapZone, on screen: NSScreen) {
        guard zone.isActive else {
            hide()
            return
        }
        guard zone != currentZone || screen != currentScreen else {
            return
        }

        currentZone = zone
        currentScreen = screen

        // Compute the inset target frame (4 px breathing room on every side).
        let rawFrame    = zone.targetFrame(screen: screen)
        let targetFrame = rawFrame.insetBy(dx: 4, dy: 4)

        // Build the window lazily; reuse on subsequent calls.
        let window = overlayWindow ?? makeOverlayWindow()
        overlayWindow = window

        // Update the embedded view's zone so it can adapt colors if needed.
        if let overlayView = window.contentView as? OverlayView {
            overlayView.zone = zone
        }

        // Position and size.
        window.setFrame(targetFrame, display: false)

        // Reset alpha before making the window visible so the fade always
        // starts from 0, even if a previous animation was interrupted.
        window.alphaValue = 0
        window.orderFront(nil)

        // Fade in to the user-configured opacity on the next run-loop turn
        // so the window has been placed first. Reading AppSettings here ensures
        // changes made in Preferences take effect immediately.
        let targetOpacity = AppSettings.shared.overlayOpacity
        DispatchQueue.main.async { [weak window] in
            window?.animator().alphaValue = targetOpacity
        }
    }

    /// Hide the overlay immediately (no animation).
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow?.alphaValue = 0
        currentZone = .none
        currentScreen = nil
    }

    // MARK: Private Helpers

    /// Construct and configure the overlay NSWindow exactly once.
    private func makeOverlayWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: true
        )

        // Appearance
        window.isOpaque        = false
        window.backgroundColor = .clear
        window.alphaValue      = 0

        // Behaviour
        window.level               = .screenSaver
        window.ignoresMouseEvents  = true
        window.collectionBehavior  = [.canJoinAllSpaces, .stationary]

        // The window must not steal focus from the window being dragged.
        window.isReleasedWhenClosed = false

        // Attach the drawing view.
        let overlayView = OverlayView()
        overlayView.autoresizingMask = [.width, .height]
        window.contentView = overlayView

        return window
    }
}
