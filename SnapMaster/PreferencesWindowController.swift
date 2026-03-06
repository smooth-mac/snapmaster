import AppKit

// MARK: - PreferencesWindowController

/// A singleton `NSWindowController` that hosts the SnapMaster Preferences UI.
///
/// Layout is built entirely in code — no XIB or Storyboard required.
/// All slider changes are written to `AppSettings.shared` immediately so that
/// `SnapZoneDetector` and `OverlayWindowManager` pick them up on the next event.
final class PreferencesWindowController: NSWindowController {

    // MARK: - Singleton

    static let shared = PreferencesWindowController()

    // MARK: - Init

    private init() {
        let windowRect = NSRect(x: 0, y: 0, width: 460, height: 400)
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.styleMask.remove(.resizable)
        window.styleMask.remove(.miniaturizable)

        super.init(window: window)

        let vc = PreferencesViewController()
        window.contentViewController = vc
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    /// Bring the Preferences window to the front, centering it on first open.
    override func showWindow(_ sender: Any?) {
        guard let window = self.window else { return }
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - PreferencesViewController

private final class PreferencesViewController: NSViewController {

    // MARK: - UI elements

    private var edgeSlider:     NSSlider!
    private var edgeLabel:      NSTextField!
    private var cornerSlider:   NSSlider!
    private var cornerLabel:    NSTextField!
    private var opacitySlider:  NSSlider!
    private var opacityLabel:   NSTextField!
    private var tableView:      NSTableView!
    private var removeButton:   NSButton!

    // MARK: - Derived data

    /// Mutable copy of the exclusion list kept in sync with AppSettings.
    private var excludedBundleIDs: [String] = AppSettings.shared.excludedBundleIDs

    /// Cache of bundleID → app name from running applications.
    /// Rebuilt once per reloadData() call to avoid O(n) NSWorkspace lookups per cell.
    private var runningAppNames: [String: String] = [:]

    // MARK: - Cell identifier

    private static let bundleCellID = NSUserInterfaceItemIdentifier("BundleIDCell")

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        syncControlsFromSettings()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        excludedBundleIDs = AppSettings.shared.excludedBundleIDs
        refreshRunningAppNames()
        tableView.reloadData()
    }

    // MARK: - UI Construction

    private func buildUI() {
        // ── Section: Snap Sensitivity ──────────────────────────────────────

        let snapHeader = makeSectionHeader("Snap Sensitivity")
        view.addSubview(snapHeader)

        let edgeTitleLabel = makeLabel("Edge threshold:")
        view.addSubview(edgeTitleLabel)

        edgeSlider = makeSlider(
            min: Double(AppSettings.Range.edgeThreshold.lowerBound),
            max: Double(AppSettings.Range.edgeThreshold.upperBound),
            action: #selector(edgeSliderChanged(_:))
        )
        view.addSubview(edgeSlider)

        edgeLabel = makeValueLabel()
        view.addSubview(edgeLabel)

        let cornerTitleLabel = makeLabel("Corner threshold:")
        view.addSubview(cornerTitleLabel)

        cornerSlider = makeSlider(
            min: Double(AppSettings.Range.cornerThreshold.lowerBound),
            max: Double(AppSettings.Range.cornerThreshold.upperBound),
            action: #selector(cornerSliderChanged(_:))
        )
        view.addSubview(cornerSlider)

        cornerLabel = makeValueLabel()
        view.addSubview(cornerLabel)

        // ── Section: Overlay ───────────────────────────────────────────────

        let overlayHeader = makeSectionHeader("Overlay")
        view.addSubview(overlayHeader)

        let opacityTitleLabel = makeLabel("Opacity:")
        view.addSubview(opacityTitleLabel)

        opacitySlider = makeSlider(
            min: AppSettings.Range.overlayOpacity.lowerBound,
            max: AppSettings.Range.overlayOpacity.upperBound,
            action: #selector(opacitySliderChanged(_:))
        )
        view.addSubview(opacitySlider)

        opacityLabel = makeValueLabel()
        view.addSubview(opacityLabel)

        // ── Section: Excluded Apps ─────────────────────────────────────────

        let excludedHeader = makeSectionHeader("Excluded Apps")
        view.addSubview(excludedHeader)

        let scrollView = buildExcludedAppsTableView()
        view.addSubview(scrollView)

        let addButton = NSButton(title: "+ Add", target: self, action: #selector(addExcludedApp(_:)))
        addButton.bezelStyle = .rounded
        addButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addButton)

        removeButton = NSButton(title: "- Remove", target: self, action: #selector(removeExcludedApp(_:)))
        removeButton.bezelStyle = .rounded
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(removeButton)

        // ── Auto Layout ────────────────────────────────────────────────────

        // Column layout constants
        let leadingMargin:   CGFloat = 20
        let sliderLeading:   CGFloat = 152
        let labelWidth:      CGFloat = 64
        let rowHeight:       CGFloat = 24
        let sectionSpacing:  CGFloat = 20
        let rowSpacing:      CGFloat = 10

        NSLayoutConstraint.activate([

            // Snap Sensitivity header
            snapHeader.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            snapHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),

            // Edge row
            edgeTitleLabel.topAnchor.constraint(equalTo: snapHeader.bottomAnchor, constant: rowSpacing),
            edgeTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            edgeTitleLabel.widthAnchor.constraint(equalToConstant: 130),
            edgeTitleLabel.heightAnchor.constraint(equalToConstant: rowHeight),

            edgeSlider.centerYAnchor.constraint(equalTo: edgeTitleLabel.centerYAnchor),
            edgeSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sliderLeading),
            edgeSlider.trailingAnchor.constraint(equalTo: edgeLabel.leadingAnchor, constant: -8),

            edgeLabel.centerYAnchor.constraint(equalTo: edgeTitleLabel.centerYAnchor),
            edgeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            edgeLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            // Corner row
            cornerTitleLabel.topAnchor.constraint(equalTo: edgeTitleLabel.bottomAnchor, constant: rowSpacing),
            cornerTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            cornerTitleLabel.widthAnchor.constraint(equalToConstant: 130),
            cornerTitleLabel.heightAnchor.constraint(equalToConstant: rowHeight),

            cornerSlider.centerYAnchor.constraint(equalTo: cornerTitleLabel.centerYAnchor),
            cornerSlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sliderLeading),
            cornerSlider.trailingAnchor.constraint(equalTo: cornerLabel.leadingAnchor, constant: -8),

            cornerLabel.centerYAnchor.constraint(equalTo: cornerTitleLabel.centerYAnchor),
            cornerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cornerLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            // Overlay header
            overlayHeader.topAnchor.constraint(equalTo: cornerTitleLabel.bottomAnchor, constant: sectionSpacing),
            overlayHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),

            // Opacity row
            opacityTitleLabel.topAnchor.constraint(equalTo: overlayHeader.bottomAnchor, constant: rowSpacing),
            opacityTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            opacityTitleLabel.widthAnchor.constraint(equalToConstant: 130),
            opacityTitleLabel.heightAnchor.constraint(equalToConstant: rowHeight),

            opacitySlider.centerYAnchor.constraint(equalTo: opacityTitleLabel.centerYAnchor),
            opacitySlider.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: sliderLeading),
            opacitySlider.trailingAnchor.constraint(equalTo: opacityLabel.leadingAnchor, constant: -8),

            opacityLabel.centerYAnchor.constraint(equalTo: opacityTitleLabel.centerYAnchor),
            opacityLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            opacityLabel.widthAnchor.constraint(equalToConstant: labelWidth),

            // Excluded Apps header
            excludedHeader.topAnchor.constraint(equalTo: opacityTitleLabel.bottomAnchor, constant: sectionSpacing),
            excludedHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),

            // Table view
            scrollView.topAnchor.constraint(equalTo: excludedHeader.bottomAnchor, constant: rowSpacing),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -8),

            // Add / Remove buttons
            addButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            addButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: leadingMargin),
            addButton.widthAnchor.constraint(equalToConstant: 80),

            removeButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
            removeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            removeButton.widthAnchor.constraint(equalToConstant: 90),
        ])
    }

    /// Build the scrollable table that shows excluded bundle IDs.
    private func buildExcludedAppsTableView() -> NSScrollView {
        let column = NSTableColumn(identifier: Self.bundleCellID)
        column.title = "Bundle Identifier"
        column.resizingMask = .autoresizingMask

        tableView = NSTableView()
        tableView.addTableColumn(column)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = NSTableHeaderView()
        tableView.rowHeight = 20
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.selectionHighlightStyle = .regular

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        return scrollView
    }

    // MARK: - Control Factories

    private func makeSectionHeader(_ title: String) -> NSTextField {
        let tf = NSTextField(labelWithString: title)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.font = NSFont.boldSystemFont(ofSize: 11)
        tf.textColor = .secondaryLabelColor
        return tf
    }

    private func makeLabel(_ title: String) -> NSTextField {
        let tf = NSTextField(labelWithString: title)
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.alignment = .right
        return tf
    }

    private func makeValueLabel() -> NSTextField {
        let tf = NSTextField(labelWithString: "")
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.alignment = .left
        tf.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        return tf
    }

    private func makeSlider(min: Double, max: Double, action: Selector) -> NSSlider {
        let slider = NSSlider(value: min, minValue: min, maxValue: max, target: self, action: action)
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.controlSize = .small
        return slider
    }

    // MARK: - Sync helpers

    /// Populate all controls from the current `AppSettings.shared` values.
    private func syncControlsFromSettings() {
        let s = AppSettings.shared

        edgeSlider.doubleValue   = Double(s.edgeThreshold)
        cornerSlider.doubleValue = Double(s.cornerThreshold)
        opacitySlider.doubleValue = s.overlayOpacity

        updateEdgeLabel()
        updateCornerLabel()
        updateOpacityLabel()
    }

    private func updateEdgeLabel() {
        edgeLabel.stringValue = "\(Int(edgeSlider.doubleValue)) px"
    }

    private func updateCornerLabel() {
        cornerLabel.stringValue = "\(Int(cornerSlider.doubleValue)) px"
    }

    private func updateOpacityLabel() {
        let pct = Int((opacitySlider.doubleValue * 100).rounded())
        opacityLabel.stringValue = "\(pct)%"
    }

    // MARK: - Slider Actions

    @objc private func edgeSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        AppSettings.shared.edgeThreshold = value
        updateEdgeLabel()
    }

    @objc private func cornerSliderChanged(_ sender: NSSlider) {
        let value = CGFloat(sender.doubleValue)
        AppSettings.shared.cornerThreshold = value
        updateCornerLabel()
    }

    @objc private func opacitySliderChanged(_ sender: NSSlider) {
        AppSettings.shared.overlayOpacity = sender.doubleValue
        updateOpacityLabel()
    }

    // MARK: - Excluded Apps Actions

    /// Shows a menu with two options:
    ///   - "Enter Bundle ID..." — opens a text-input sheet
    ///   - "Running Apps..." — submenu listing currently active regular apps
    @objc private func addExcludedApp(_ sender: NSButton) {
        let menu = NSMenu()

        // Option 1: manual bundle ID entry
        let enterItem = NSMenuItem(
            title: "Enter Bundle ID...",
            action: #selector(enterBundleIDManually(_:)),
            keyEquivalent: ""
        )
        enterItem.target = self
        menu.addItem(enterItem)

        menu.addItem(.separator())

        // Option 2: running apps submenu
        let runningSubmenuItem = NSMenuItem(title: "Running Apps...", action: nil, keyEquivalent: "")
        runningSubmenuItem.submenu = buildRunningAppsSubmenu()
        menu.addItem(runningSubmenuItem)

        let buttonOrigin = sender.convert(sender.bounds.origin, to: nil)
        let screenPoint  = sender.window?.convertPoint(toScreen: buttonOrigin) ?? .zero
        menu.popUp(positioning: nil, at: screenPoint, in: nil)
    }

    /// Builds the submenu that lists all currently running regular applications
    /// whose bundle IDs are not already in the exclusion list.
    private func buildRunningAppsSubmenu() -> NSMenu {
        let submenu = NSMenu()
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier,
                  !excludedBundleIDs.contains(bundleID) else { continue }

            let title = app.localizedName ?? bundleID
            let item = NSMenuItem(
                title: title,
                action: #selector(didSelectApp(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = bundleID

            // Show the app icon at 16×16 if available.
            if let icon = app.icon {
                let sized = NSImage(size: NSSize(width: 16, height: 16))
                sized.lockFocus()
                icon.draw(in: NSRect(origin: .zero, size: NSSize(width: 16, height: 16)))
                sized.unlockFocus()
                item.image = sized
            }

            submenu.addItem(item)
        }

        if submenu.items.isEmpty {
            let empty = NSMenuItem(title: "No running apps to add", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
        }

        return submenu
    }

    /// Presents an `NSAlert` with a text field so the user can type a bundle ID
    /// directly.  The input is validated before being added to the exclusion list.
    @objc private func enterBundleIDManually(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Add Bundle ID"
        alert.informativeText = "Enter the bundle identifier of the app to exclude (e.g. com.company.AppName)."
        alert.addButton(withTitle: "Add")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 22))
        textField.placeholderString = "com.example.MyApp"
        alert.accessoryView = textField

        // Present the sheet attached to the preferences window if possible;
        // otherwise fall back to a modal dialog.
        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                self?.commitBundleIDEntry(from: textField)
            }
        } else {
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                commitBundleIDEntry(from: textField)
            }
        }
    }

    /// Validates and persists the bundle ID entered in `textField`.
    ///
    /// Rules:
    ///   - Must not be empty after trimming whitespace
    ///   - Must contain at least one dot (reverse-domain format check)
    ///   - Must not already be in the exclusion list
    private func commitBundleIDEntry(from textField: NSTextField) {
        let raw = textField.stringValue.trimmingCharacters(in: .whitespaces)

        let errorMessage: String?
        if raw.isEmpty {
            errorMessage = "Bundle ID cannot be empty."
        } else if !raw.contains(".") {
            errorMessage = "\"\(raw)\" doesn't look like a bundle identifier.\nUse reverse-domain format, e.g. com.company.AppName."
        } else if excludedBundleIDs.contains(raw) {
            errorMessage = "\"\(raw)\" is already in the exclusion list."
        } else {
            errorMessage = nil
        }

        if let message = errorMessage {
            let err = NSAlert()
            err.messageText = "Invalid Bundle ID"
            err.informativeText = message
            err.alertStyle = .warning
            err.addButton(withTitle: "OK")
            if let window = view.window {
                err.beginSheetModal(for: window)
            } else {
                err.runModal()
            }
            return
        }

        excludedBundleIDs.append(raw)
        AppSettings.shared.excludedBundleIDs = excludedBundleIDs
        refreshRunningAppNames()
        tableView.reloadData()
    }

    @objc private func didSelectApp(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        excludedBundleIDs.append(bundleID)
        AppSettings.shared.excludedBundleIDs = excludedBundleIDs
        refreshRunningAppNames()
        tableView.reloadData()
    }

    @objc private func removeExcludedApp(_ sender: NSButton) {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < excludedBundleIDs.count else { return }
        excludedBundleIDs.remove(at: selectedRow)
        AppSettings.shared.excludedBundleIDs = excludedBundleIDs
        refreshRunningAppNames()
        tableView.reloadData()
    }

    // MARK: - Display name helpers

    /// Rebuilds `runningAppNames` from the current running applications.
    /// Call this once before `tableView.reloadData()`.
    private func refreshRunningAppNames() {
        runningAppNames = NSWorkspace.shared.runningApplications
            .reduce(into: [:]) { dict, app in
                if let id = app.bundleIdentifier, let name = app.localizedName {
                    dict[id] = name
                }
            }
    }

    /// Returns a display string for a bundle ID using the cached app name map.
    private func displayName(for bundleID: String) -> String {
        guard let name = runningAppNames[bundleID] else { return bundleID }
        return "\(name) (\(bundleID))"
    }
}

// MARK: - NSTableViewDataSource

extension PreferencesViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        excludedBundleIDs.count
    }
}

// MARK: - NSTableViewDelegate

extension PreferencesViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cellID = PreferencesViewController.bundleCellID
        var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView

        if cell == nil {
            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.lineBreakMode = .byTruncatingMiddle

            let view = NSTableCellView()
            view.identifier = cellID
            view.textField = textField
            view.addSubview(textField)

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])

            cell = view
        }

        cell?.textField?.stringValue = displayName(for: excludedBundleIDs[row])
        return cell
    }
}
