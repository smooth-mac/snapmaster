import AppKit
import ServiceManagement

/// Manages the NSStatusItem that lives in the macOS menu bar.
///
/// Responsibilities:
/// - Display the SnapMaster icon in the status bar.
/// - Provide a menu to toggle snapping on/off, open Accessibility settings,
///   and quit the application.
/// - Notify the rest of the app via `onToggle` whenever `isEnabled` changes.
final class MenuBarManager {

    // MARK: Public State

    /// Whether window snapping is globally active.
    /// Toggled via the "Enabled" menu item; changing this value directly also
    /// refreshes the menu checkmark automatically.
    var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue else { return }
            updateMenu()
            onToggle?(isEnabled)
        }
    }

    /// Called whenever `isEnabled` changes, passing the new value.
    var onToggle: ((Bool) -> Void)?

    /// Called when the user clicks "Shortcuts…".
    var onOpenShortcuts: (() -> Void)?

    /// Called when the user clicks "Preferences…".
    var onOpenPreferences: (() -> Void)?

    // MARK: Private State

    private let statusItem: NSStatusItem
    private let menu: NSMenu

    // Tags used to locate menu items without storing extra references.
    private enum ItemTag: Int {
        case enabledToggle      = 1
        case accessibilityOpen  = 2
        case shortcuts          = 3
        case launchAtLogin      = 4
        case preferences        = 5
    }

    // MARK: Init

    init() {
        menu       = NSMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        configureIcon()
        buildMenu()
    }

    // MARK: Public Interface

    /// Rebuild the checkmark states on stateful menu items.
    /// Call this whenever external code mutates `isEnabled` directly
    /// (e.g. after an accessibility-permission change at launch).
    func updateMenu() {
        if let item = menu.item(withTag: ItemTag.enabledToggle.rawValue) {
            item.state = isEnabled ? .on : .off
        }
        if let item = menu.item(withTag: ItemTag.launchAtLogin.rawValue) {
            item.state = AppSettings.shared.launchAtLogin ? .on : .off
        }
    }

    // MARK: Private – Icon

    private func configureIcon() {
        if let button = statusItem.button {
            if let sfImage = NSImage(
                systemSymbolName: "rectangle.split.2x2",
                accessibilityDescription: "SnapMaster"
            ) {
                // Template images automatically adopt the correct appearance
                // (light / dark, active / inactive) in the menu bar.
                sfImage.isTemplate = true
                button.image       = sfImage
            } else {
                // Fallback for older SDKs or environments without the symbol.
                button.title = "⊞"
            }

            button.toolTip = "SnapMaster"
        }

        statusItem.menu = menu
    }

    // MARK: Private – Menu Construction

    private func buildMenu() {
        // ── App title (non-interactive label) ──────────────────────────────
        let titleItem = NSMenuItem(title: "SnapMaster", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        // ── Enabled toggle ─────────────────────────────────────────────────
        let enabledItem = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.tag    = ItemTag.enabledToggle.rawValue
        enabledItem.state  = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        // ── Launch at Login ────────────────────────────────────────────────
        let launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.tag    = ItemTag.launchAtLogin.rawValue
        launchAtLoginItem.state  = AppSettings.shared.launchAtLogin ? .on : .off
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        // ── Preferences ────────────────────────────────────────────────────
        let preferencesItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.tag    = ItemTag.preferences.rawValue
        menu.addItem(preferencesItem)

        // ── Shortcuts ──────────────────────────────────────────────────────
        let shortcutsItem = NSMenuItem(
            title: "Shortcuts\u{2026}",
            action: #selector(openShortcuts(_:)),
            keyEquivalent: ""
        )
        shortcutsItem.target = self
        shortcutsItem.tag    = ItemTag.shortcuts.rawValue
        menu.addItem(shortcutsItem)

        menu.addItem(.separator())

        // ── Accessibility Settings ─────────────────────────────────────────
        let accessibilityItem = NSMenuItem(
            title: "Accessibility Settings\u{2026}",
            action: #selector(openAccessibilitySettings(_:)),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.tag    = ItemTag.accessibilityOpen.rawValue
        menu.addItem(accessibilityItem)

        menu.addItem(.separator())

        // ── Quit ───────────────────────────────────────────────────────────
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        // Targeting nil lets the responder chain route terminate(_:) to NSApp.
        quitItem.target = nil
        menu.addItem(quitItem)
    }

    // MARK: Private – Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        // Flip the backing property; the didSet observer updates the UI and
        // fires the callback.
        isEnabled.toggle()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        // Flip the stored value; AppSettings.launchAtLogin.setter handles
        // the actual SMAppService register/unregister call.
        let newValue = !AppSettings.shared.launchAtLogin
        AppSettings.shared.launchAtLogin = newValue
        sender.state = newValue ? .on : .off
    }

    @objc private func openPreferences(_ sender: NSMenuItem) {
        onOpenPreferences?()
    }

    @objc private func openShortcuts(_ sender: NSMenuItem) {
        onOpenShortcuts?()
    }

    @objc private func openAccessibilitySettings(_ sender: NSMenuItem) {
        // Deep-link directly into Privacy & Security > Accessibility.
        // This URL is supported on macOS 13 Ventura and later.
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
