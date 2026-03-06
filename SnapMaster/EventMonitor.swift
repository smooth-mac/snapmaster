import AppKit

// MARK: - Delegate

protocol EventMonitorDelegate: AnyObject {
    func eventMonitor(_ monitor: EventMonitor, didDetectZone zone: SnapZone, on screen: NSScreen)
    func eventMonitor(_ monitor: EventMonitor, didSnapTo zone: SnapZone, on screen: NSScreen)
    func eventMonitorDidCancelSnap(_ monitor: EventMonitor)
}

// MARK: - EventMonitor

/// Listens to global mouse events via NSEvent global monitors and drives the snap workflow.
///
/// Uses `NSEvent.addGlobalMonitorForEvents(matching:handler:)` instead of CGEventTap,
/// which is compatible with the Mac App Store sandbox policy.
///
/// Flow:
///   leftMouseDown  → record drag start
///   leftMouseDragged → detect zone, notify delegate to show preview
///   leftMouseUp    → if zone active, apply snap; else cancel
///
/// NSEvent global monitor callbacks are delivered on the main thread, so delegate
/// calls are made directly without `DispatchQueue.main.async` wrapping.
final class EventMonitor {

    weak var delegate: EventMonitorDelegate?

    // Internal snap-zone detector — not exposed outside EventMonitor.
    private var detector = SnapZoneDetector()

    // State
    private var isDragging = false
    private var currentZone: SnapZone = .none
    private var currentScreen: NSScreen?

    // NSEvent global monitor tokens
    private var mouseDownMonitor: Any?
    private var mouseDragMonitor: Any?
    private var mouseUpMonitor:   Any?

    // MARK: - Lifecycle

    func start() {
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleMouseDown(event)
        }
        mouseDragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleMouseDragged(event)
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            self?.handleMouseUp(event)
        }
        print("[EventMonitor] Started (NSEvent global monitors)")
    }

    func stop() {
        [mouseDownMonitor, mouseDragMonitor, mouseUpMonitor]
            .compactMap { $0 }
            .forEach { NSEvent.removeMonitor($0) }
        mouseDownMonitor = nil
        mouseDragMonitor = nil
        mouseUpMonitor   = nil
        print("[EventMonitor] Stopped")
    }

    // MARK: - Excluded-app guard

    /// Returns `true` when the frontmost application's bundle ID is in the
    /// user's exclusion list, meaning snapping should be suppressed.
    ///
    /// `NSWorkspace.shared.frontmostApplication` is safe to read from the
    /// main thread (all NSEvent global monitor callbacks arrive on main).
    private func isDraggingExcludedApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return AppSettings.shared.excludedBundleIDs.contains(bundleID)
    }

    // MARK: - Coordinate conversion

    /// Converts an AppKit NSPoint (bottom-left origin, Y up) to a CGPoint
    /// (top-left origin, Y down) suitable for `SnapZoneDetector.detect(at:)`.
    ///
    /// Uses `NSScreen.screens.first?.frame.height` (the primary display height)
    /// as the reference, which matches the CG global coordinate space.
    private func cgPoint(from nsPoint: NSPoint) -> CGPoint {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: nsPoint.x, y: screenHeight - nsPoint.y)
    }

    // MARK: - Mouse event handlers

    private func handleMouseDown(_ event: NSEvent) {
        guard !isDraggingExcludedApp() else { return }
        isDragging = true
        currentZone = .none
        currentScreen = nil
    }

    private func handleMouseDragged(_ event: NSEvent) {
        guard isDragging else { return }
        guard !isDraggingExcludedApp() else { return }

        let loc = cgPoint(from: NSEvent.mouseLocation)

        if let (zone, screen) = detector.detect(at: loc) {
            if zone != currentZone {
                currentZone = zone
                currentScreen = screen
                delegate?.eventMonitor(self, didDetectZone: zone, on: screen)
            }
        } else if currentZone != .none {
            currentZone = .none
            currentScreen = nil
            delegate?.eventMonitorDidCancelSnap(self)
        }
    }

    private func handleMouseUp(_ event: NSEvent) {
        guard isDragging else { return }
        isDragging = false

        let zone = currentZone
        let screen = currentScreen
        currentZone = .none
        currentScreen = nil

        if zone.isActive, let screen {
            delegate?.eventMonitor(self, didSnapTo: zone, on: screen)
        } else {
            delegate?.eventMonitorDidCancelSnap(self)
        }
    }
}
