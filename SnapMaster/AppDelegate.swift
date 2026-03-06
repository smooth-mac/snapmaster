import AppKit
import ServiceManagement

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Core components

    private var menuBarManager: MenuBarManager!
    private var eventMonitor: EventMonitor!
    private var overlayManager: OverlayWindowManager!
    private var hotkeyManager: HotkeyManager!

    // MARK: - Windows

    private var shortcutsWindowController: ShortcutsWindowController?

    // MARK: - State

    private var isEnabled: Bool = true

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Align the stored launch-at-login preference with the actual
        // SMAppService registration state. This handles edge cases where
        // the user toggled the setting outside the app (e.g. System Settings).
        AppSettings.shared.syncLaunchAtLoginState()
        setupComponents()
        checkAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        eventMonitor.stop()
        hotkeyManager.stop()
    }

    // MARK: - Setup

    private func setupComponents() {
        overlayManager  = OverlayWindowManager()
        hotkeyManager   = HotkeyManager()

        menuBarManager  = MenuBarManager()
        menuBarManager.onToggle = { [weak self] enabled in
            guard let self else { return }
            self.isEnabled = enabled
            if enabled {
                self.eventMonitor.start()
                self.hotkeyManager.start()
            } else {
                self.eventMonitor.stop()
                self.hotkeyManager.stop()
                self.overlayManager.hide()
            }
        }
        menuBarManager.onOpenShortcuts = { [weak self] in
            self?.showShortcutsWindow()
        }
        menuBarManager.onOpenPreferences = {
            PreferencesWindowController.shared.showWindow(nil)
        }

        eventMonitor = EventMonitor()
        eventMonitor.delegate = self
        eventMonitor.start()

        hotkeyManager.start()
    }

    // MARK: - Shortcuts window

    private func showShortcutsWindow() {
        if shortcutsWindowController == nil {
            shortcutsWindowController = ShortcutsWindowController(hotkeyManager: hotkeyManager)
        }
        shortcutsWindowController?.showWindow()
    }

    // MARK: - Accessibility

    private func checkAccessibility() {
        if !WindowController.isAccessibilityGranted {
            showAccessibilityAlert()
        }
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
            SnapMaster needs Accessibility access to detect and move windows.

            Click "Open Settings" to grant permission, then restart SnapMaster.
            """
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Later")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            WindowController.requestAccessibility()
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - EventMonitorDelegate

extension AppDelegate: EventMonitorDelegate {

    func eventMonitor(_ monitor: EventMonitor, didDetectZone zone: SnapZone, on screen: NSScreen) {
        guard isEnabled else { return }
        overlayManager.show(zone: zone, on: screen)
    }

    func eventMonitor(_ monitor: EventMonitor, didSnapTo zone: SnapZone, on screen: NSScreen) {
        guard isEnabled else { return }
        overlayManager.hide()

        guard WindowController.isAccessibilityGranted else {
            showAccessibilityAlert()
            return
        }
        guard let window = WindowController.getFrontmostWindow() else {
            print("[AppDelegate] No frontmost window to snap")
            return
        }

        let targetFrame = zone.targetFrame(screen: screen)
        WindowController.setFrame(targetFrame, for: window)
        print("[AppDelegate] Drag-snapped to \(zone.displayName) → \(targetFrame)")
    }

    func eventMonitorDidCancelSnap(_ monitor: EventMonitor) {
        overlayManager.hide()
    }
}
