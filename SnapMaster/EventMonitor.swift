import AppKit
import CoreGraphics

// MARK: - Delegate

protocol EventMonitorDelegate: AnyObject {
    func eventMonitor(_ monitor: EventMonitor, didDetectZone zone: SnapZone, on screen: NSScreen)
    func eventMonitor(_ monitor: EventMonitor, didSnapTo zone: SnapZone, on screen: NSScreen)
    func eventMonitorDidCancelSnap(_ monitor: EventMonitor)
}

// MARK: - EventMonitor

/// Listens to global mouse events via CGEventTap and drives the snap workflow.
///
/// Flow:
///   leftMouseDown  → record drag start
///   leftMouseDragged → detect zone, notify delegate to show preview
///   leftMouseUp    → if zone active, apply snap; else cancel
final class EventMonitor {

    weak var delegate: EventMonitorDelegate?

    // Internal snap-zone detector — not exposed outside EventMonitor.
    private var detector = SnapZoneDetector()

    // State
    private var isDragging = false
    private var currentZone: SnapZone = .none
    private var currentScreen: NSScreen?

    // CGEventTap
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Lifecycle

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue)    |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<EventMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            print("[EventMonitor] Failed to create event tap — check Accessibility permission")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[EventMonitor] Started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        print("[EventMonitor] Stopped")
    }

    // MARK: - Excluded-app guard

    /// Returns `true` when the frontmost application's bundle ID is in the
    /// user's exclusion list, meaning snapping should be suppressed.
    ///
    /// `NSWorkspace.shared.frontmostApplication` is safe to read from any
    /// thread (it is an atomic property backed by the workspace server).
    private func isDraggingExcludedApp() -> Bool {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else {
            return false
        }
        return AppSettings.shared.excludedBundleIDs.contains(bundleID)
    }

    // MARK: - Event handling

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .leftMouseDown:
            guard !isDraggingExcludedApp() else { return }
            isDragging = true
            currentZone = .none
            currentScreen = nil

        case .leftMouseDragged:
            guard isDragging else { return }
            guard !isDraggingExcludedApp() else { return }
            let loc = event.location
            if let (zone, screen) = detector.detect(at: loc) {
                if zone != currentZone {
                    currentZone = zone
                    currentScreen = screen
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.delegate?.eventMonitor(self, didDetectZone: zone, on: screen)
                    }
                }
            } else if currentZone != .none {
                currentZone = .none
                currentScreen = nil
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.delegate?.eventMonitorDidCancelSnap(self)
                }
            }

        case .leftMouseUp:
            guard isDragging else { return }
            isDragging = false

            let zone = currentZone
            let screen = currentScreen
            currentZone = .none
            currentScreen = nil

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if zone.isActive, let screen {
                    self.delegate?.eventMonitor(self, didSnapTo: zone, on: screen)
                } else {
                    self.delegate?.eventMonitorDidCancelSnap(self)
                }
            }

        default:
            break
        }
    }
}
