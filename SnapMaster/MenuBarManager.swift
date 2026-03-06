import AppKit
import ServiceManagement

/// Manages the NSStatusItem that lives in the macOS menu bar.
///
/// Responsibilities:
/// - Display the SnapMaster icon in the status bar, reflecting enabled/disabled state.
/// - Provide a quick-access menu for toggling snapping, adjusting sensitivity,
///   enabling/disabling individual snap zone groups, and launching preferences.
/// - Notify the rest of the app via `onToggle` whenever `isEnabled` changes.
final class MenuBarManager: NSObject {

    // MARK: - Public State

    /// Whether window snapping is globally active.
    /// Toggled via the "Enabled" menu item; changing this value directly also
    /// refreshes the menu header and icon state automatically.
    var isEnabled: Bool = true {
        didSet {
            guard isEnabled != oldValue else { return }
            updateMenu()
            updateIcon()
            onToggle?(isEnabled)
        }
    }

    /// Called whenever `isEnabled` changes, passing the new value.
    var onToggle: ((Bool) -> Void)?

    /// Called when the user clicks "Shortcuts…".
    var onOpenShortcuts: (() -> Void)?

    /// Called when the user clicks "Preferences…".
    var onOpenPreferences: (() -> Void)?

    // MARK: - Sensitivity Presets

    /// A named sensitivity preset combining edge and corner thresholds.
    private struct SensitivityPreset {
        let title: String
        let edgeThreshold: CGFloat
        let cornerThreshold: CGFloat
    }

    /// The three ordered sensitivity presets shown in the Sensitivity submenu.
    private let sensitivityPresets: [SensitivityPreset] = [
        SensitivityPreset(title: "Low (12 px)",    edgeThreshold: 12, cornerThreshold: 80),
        SensitivityPreset(title: "Medium (24 px)", edgeThreshold: 24, cornerThreshold: 120),
        SensitivityPreset(title: "High (48 px)",   edgeThreshold: 48, cornerThreshold: 180),
    ]

    // MARK: - Snap Zone Groups

    /// A logical group of snap zones that is toggled as a unit in the Snap Zones submenu.
    private struct ZoneGroup {
        let title: String
        let zones: [SnapZone]
    }

    /// The ordered zone groups shown in the Snap Zones submenu.
    private let zoneGroups: [ZoneGroup] = [
        ZoneGroup(title: "Halves (Left / Right)", zones: [.left, .right]),
        ZoneGroup(title: "Maximize (Top)",         zones: [.top]),
        ZoneGroup(title: "Thirds (Bottom edge)",   zones: [.leftThird, .centerThird, .rightThird]),
        ZoneGroup(title: "Corners",                zones: [.topLeft, .topRight, .bottomLeft, .bottomRight]),
        ZoneGroup(title: "Bottom Half",            zones: [.bottom]),
    ]

    // MARK: - Private State

    private let statusItem: NSStatusItem
    private let menu: NSMenu

    // Tags used to locate specific menu items without storing extra references.
    private enum ItemTag: Int {
        case header             = 1
        case enabledToggle      = 2
        case launchAtLogin      = 3
        case accessibilityOpen  = 4
        case shortcuts          = 5
        case preferences        = 6
        // Sensitivity preset items: 100, 101, 102
        // Zone group items:         200, 201, 202, 203, 204
    }

    private enum SensitivityTag {
        static let base = 100
    }

    private enum ZoneGroupTag {
        static let base = 200
    }

    // MARK: - Init

    override init() {
        menu       = NSMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        menu.delegate = self
        configureIcon()
        buildMenu()
    }

    // MARK: - Public Interface

    /// Rebuild all stateful menu items (header text, checkmarks, icon).
    /// Call this whenever external code mutates `isEnabled` directly
    /// (e.g. after an accessibility-permission change at launch).
    func updateMenu() {
        updateHeader()
        updateEnabledToggle()
        updateSensitivityCheckmarks()
        updateZoneGroupCheckmarks()
        updateLaunchAtLoginCheckmark()
    }

    // MARK: - Private – Icon

    private func configureIcon() {
        guard let button = statusItem.button else { return }

        let symbolName = "square.split.2x2.fill"
        if let sfImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: "SnapMaster") {
            sfImage.isTemplate = true
            button.image       = sfImage
        } else {
            button.title = "⊞"
        }

        button.toolTip = "SnapMaster"
        statusItem.menu = menu
    }

    /// Reflects the enabled/disabled state on the status bar button.
    private func updateIcon() {
        statusItem.button?.appearsDisabled = !isEnabled
    }

    // MARK: - Private – Menu Construction

    private func buildMenu() {
        buildHeaderSection()
        menu.addItem(.separator())
        buildEnabledSection()
        menu.addItem(.separator())
        buildSensitivitySection()
        menu.addItem(.separator())
        buildSnapZonesSection()
        menu.addItem(.separator())
        buildPreferencesSection()
        menu.addItem(.separator())
        buildSystemSection()
        menu.addItem(.separator())
        buildQuitSection()
    }

    // ── Header ───────────────────────────────────────────────────────────────

    private func buildHeaderSection() {
        let headerItem = NSMenuItem(title: headerTitle(), action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        headerItem.tag       = ItemTag.header.rawValue
        menu.addItem(headerItem)
    }

    private func headerTitle() -> String {
        let statusLabel = isEnabled ? "활성 중" : "일시정지"
        return "SnapMaster  ·  \(statusLabel)"
    }

    private func updateHeader() {
        menu.item(withTag: ItemTag.header.rawValue)?.title = headerTitle()
    }

    // ── Enabled toggle ───────────────────────────────────────────────────────

    private func buildEnabledSection() {
        let item = NSMenuItem(
            title: "Enabled",
            action: #selector(toggleEnabled(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.tag    = ItemTag.enabledToggle.rawValue
        item.state  = isEnabled ? .on : .off
        menu.addItem(item)
    }

    private func updateEnabledToggle() {
        menu.item(withTag: ItemTag.enabledToggle.rawValue)?.state = isEnabled ? .on : .off
    }

    // ── Sensitivity submenu ──────────────────────────────────────────────────

    private func buildSensitivitySection() {
        let parentItem  = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        let submenu     = NSMenu(title: "Sensitivity")

        let bestIndex = nearestPresetIndex()
        for (index, preset) in sensitivityPresets.enumerated() {
            let item = NSMenuItem(
                title: preset.title,
                action: #selector(selectSensitivity(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag    = SensitivityTag.base + index
            item.state  = (index == bestIndex) ? .on : .off
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }

    /// Returns the index of the preset whose `edgeThreshold` is closest to the stored value.
    private func nearestPresetIndex() -> Int {
        let current = AppSettings.shared.edgeThreshold
        let best = sensitivityPresets.enumerated().min(by: {
            abs($0.element.edgeThreshold - current) < abs($1.element.edgeThreshold - current)
        })
        return best?.offset ?? 1
    }

    private func updateSensitivityCheckmarks() {
        let bestIndex = nearestPresetIndex()
        for index in sensitivityPresets.indices {
            let tag = SensitivityTag.base + index
            menu.item(withTag: tag)?.state = (index == bestIndex) ? .on : .off
        }
    }

    // ── Snap Zones submenu ───────────────────────────────────────────────────

    private func buildSnapZonesSection() {
        let parentItem  = NSMenuItem(title: "Snap Zones", action: nil, keyEquivalent: "")
        let submenu     = NSMenu(title: "Snap Zones")

        for (index, group) in zoneGroups.enumerated() {
            let item = NSMenuItem(
                title: group.title,
                action: #selector(toggleZoneGroup(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag    = ZoneGroupTag.base + index
            item.state  = zoneGroupState(for: group)
            submenu.addItem(item)
        }

        parentItem.submenu = submenu
        menu.addItem(parentItem)
    }

    /// Returns `.on` when every zone in the group is active (not disabled).
    private func zoneGroupState(for group: ZoneGroup) -> NSControl.StateValue {
        let disabled = AppSettings.shared.disabledZones
        let allActive = group.zones.allSatisfy { !disabled.contains($0.rawValue) }
        return allActive ? .on : .off
    }

    private func updateZoneGroupCheckmarks() {
        for (index, group) in zoneGroups.enumerated() {
            let tag = ZoneGroupTag.base + index
            menu.item(withTag: tag)?.state = zoneGroupState(for: group)
        }
    }

    // ── Preferences / Shortcuts ──────────────────────────────────────────────

    private func buildPreferencesSection() {
        let preferencesItem = NSMenuItem(
            title: "Preferences\u{2026}",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        preferencesItem.tag    = ItemTag.preferences.rawValue
        menu.addItem(preferencesItem)

        let shortcutsItem = NSMenuItem(
            title: "Shortcuts\u{2026}",
            action: #selector(openShortcuts(_:)),
            keyEquivalent: ""
        )
        shortcutsItem.target = self
        shortcutsItem.tag    = ItemTag.shortcuts.rawValue
        menu.addItem(shortcutsItem)
    }

    // ── Launch at Login / Accessibility ─────────────────────────────────────

    private func buildSystemSection() {
        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.tag    = ItemTag.launchAtLogin.rawValue
        launchItem.state  = AppSettings.shared.launchAtLogin ? .on : .off
        menu.addItem(launchItem)

        let accessibilityItem = NSMenuItem(
            title: "Accessibility Settings\u{2026}",
            action: #selector(openAccessibilitySettings(_:)),
            keyEquivalent: ""
        )
        accessibilityItem.target = self
        accessibilityItem.tag    = ItemTag.accessibilityOpen.rawValue
        menu.addItem(accessibilityItem)
    }

    private func updateLaunchAtLoginCheckmark() {
        menu.item(withTag: ItemTag.launchAtLogin.rawValue)?.state =
            AppSettings.shared.launchAtLogin ? .on : .off
    }

    // ── Quit ─────────────────────────────────────────────────────────────────

    private func buildQuitSection() {
        let quitItem = NSMenuItem(
            title: "Quit SnapMaster",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        // Targeting nil lets the responder chain route terminate(_:) to NSApp.
        quitItem.target = nil
        menu.addItem(quitItem)
    }

    // MARK: - Private – Actions

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        // Flip the backing property; the didSet observer updates UI and fires callback.
        isEnabled.toggle()
    }

    @objc private func selectSensitivity(_ sender: NSMenuItem) {
        let index = sender.tag - SensitivityTag.base
        guard sensitivityPresets.indices.contains(index) else { return }
        let preset = sensitivityPresets[index]
        AppSettings.shared.edgeThreshold   = preset.edgeThreshold
        AppSettings.shared.cornerThreshold = preset.cornerThreshold
        updateSensitivityCheckmarks()
    }

    @objc private func toggleZoneGroup(_ sender: NSMenuItem) {
        let index = sender.tag - ZoneGroupTag.base
        guard zoneGroups.indices.contains(index) else { return }
        let group = zoneGroups[index]

        var disabled = AppSettings.shared.disabledZones
        let allActive = group.zones.allSatisfy { !disabled.contains($0.rawValue) }

        if allActive {
            // All zones in the group are currently active — disable the entire group.
            group.zones.forEach { disabled.insert($0.rawValue) }
        } else {
            // At least one zone is disabled — enable the entire group.
            group.zones.forEach { disabled.remove($0.rawValue) }
        }

        AppSettings.shared.disabledZones = disabled
        updateZoneGroupCheckmarks()
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
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
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - NSMenuDelegate

extension MenuBarManager: NSMenuDelegate {

    /// Called by AppKit just before the menu becomes visible.
    /// Refreshes all dynamic state so the user always sees current values,
    /// even if settings were changed via Preferences while the menu was closed.
    func menuWillOpen(_ menu: NSMenu) {
        updateMenu()
    }
}
