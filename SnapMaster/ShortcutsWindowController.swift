import AppKit
import Carbon

// MARK: - ShortcutsWindowController

final class ShortcutsWindowController: NSWindowController {

    // MARK: - Private state

    private let hotkeyManager: HotkeyManager
    private weak var contentVC: ShortcutsViewController?

    // MARK: - Init

    init(hotkeyManager: HotkeyManager) {
        self.hotkeyManager = hotkeyManager

        let windowRect = NSRect(x: 0, y: 0, width: 440, height: 360)
        let styleMask: NSWindow.StyleMask = [.titled, .closable]
        let window = NSWindow(
            contentRect: windowRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Keyboard Shortcuts"
        window.isReleasedWhenClosed = false

        // Prevent resizing and minimizing
        window.styleMask.remove(.resizable)
        window.styleMask.remove(.miniaturizable)

        super.init(window: window)

        let vc = ShortcutsViewController(hotkeyManager: hotkeyManager)
        contentVC = vc
        window.contentViewController = vc
        window.delegate = vc
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - Public API

    func showWindow() {
        guard let window = self.window else { return }
        if !window.isVisible {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - ShortcutsViewController

private final class ShortcutsViewController: NSViewController {

    // MARK: - Dependencies

    private let hotkeyManager: HotkeyManager

    // MARK: - Derived data

    /// HotkeyBindings filtered to exclude the .none zone, in a stable order.
    private var bindings: [HotkeyBinding] {
        hotkeyManager.bindings.filter { $0.zone != .none }
    }

    // MARK: - Recording state

    /// The row index currently being recorded, or nil if idle.
    private var recordingRow: Int?
    /// The local event monitor installed while recording.
    private var keyDownMonitor: Any?

    // MARK: - UI

    private var scrollView: NSScrollView!
    private var tableView: NSTableView!
    private var resetButton: NSButton!

    // MARK: - Cell identifiers

    private static let actionCellID    = NSUserInterfaceItemIdentifier("ActionCell")
    private static let shortcutCellID  = NSUserInterfaceItemIdentifier("ShortcutCell")
    private static let recordCellID    = NSUserInterfaceItemIdentifier("RecordCell")

    // MARK: - Init

    init(hotkeyManager: HotkeyManager) {
        self.hotkeyManager = hotkeyManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - View lifecycle

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 360))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
    }

    // MARK: - UI construction

    private func buildUI() {
        // --- Table columns ---

        let actionColumn = NSTableColumn(identifier: Self.actionCellID)
        actionColumn.title = "Action"
        actionColumn.width = 140
        actionColumn.resizingMask = []

        let shortcutColumn = NSTableColumn(identifier: Self.shortcutCellID)
        shortcutColumn.title = "Shortcut"
        shortcutColumn.width = 160
        shortcutColumn.resizingMask = []

        let recordColumn = NSTableColumn(identifier: Self.recordCellID)
        recordColumn.title = ""
        recordColumn.width = 100
        recordColumn.resizingMask = []

        // --- Table view ---

        tableView = NSTableView()
        tableView.addTableColumn(actionColumn)
        tableView.addTableColumn(shortcutColumn)
        tableView.addTableColumn(recordColumn)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 36
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true

        // --- Scroll view ---

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        view.addSubview(scrollView)

        // --- Reset Defaults button ---

        resetButton = NSButton(title: "Reset Defaults", target: self, action: #selector(resetDefaults))
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.bezelStyle = .rounded
        view.addSubview(resetButton)

        // --- Layout ---

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: resetButton.topAnchor, constant: -12),

            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resetButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -16),
        ])
    }

    // MARK: - Recording

    private func beginRecording(row: Int) {
        // Cancel any previous recording first
        cancelRecording()

        recordingRow = row

        // Reload just the record-button cell to show "Press key…"
        reloadRecordCell(row: row)

        // Install a local key-down monitor
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleKeyDown(event: event)
        }
    }

    /// Handles a key-down event while in recording mode.
    /// Returns nil to consume the event, or the original event to pass it through.
    private func handleKeyDown(event: NSEvent) -> NSEvent? {
        guard let row = recordingRow else { return event }

        // Escape cancels recording
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return nil
        }

        // Require at least one of: Control, Option, Command, Shift
        let modifiers = event.modifierFlags.intersection([.control, .option, .command, .shift])
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return nil
        }

        // Convert to Carbon values
        let carbonMods    = HotkeyBinding.carbonModifiers(from: event.modifierFlags)
        let carbonKeyCode = HotkeyBinding.carbonKeyCode(from: event.keyCode)

        let currentBinding = bindings[row]
        let updated = HotkeyBinding(
            id: currentBinding.id,
            zone: currentBinding.zone,
            keyCode: carbonKeyCode,
            carbonModifiers: carbonMods
        )

        hotkeyManager.rebind(updated)
        stopRecording()

        // Reload the entire row to refresh both Shortcut and Record cells
        tableView.reloadData(
            forRowIndexes: IndexSet(integer: row),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )

        return nil
    }

    private func cancelRecording() {
        guard let row = recordingRow else { return }
        stopRecording()
        reloadRecordCell(row: row)
    }

    private func stopRecording() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        recordingRow = nil
    }

    private func reloadRecordCell(row: Int) {
        let recordColumnIndex = tableView.column(withIdentifier: Self.recordCellID)
        guard recordColumnIndex >= 0 else { return }
        tableView.reloadData(
            forRowIndexes: IndexSet(integer: row),
            columnIndexes: IndexSet(integer: recordColumnIndex)
        )
    }

    // MARK: - Actions

    @objc private func resetDefaults() {
        cancelRecording()
        hotkeyManager.resetDefaults()
        tableView.reloadData()
    }

    @objc private func recordButtonClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0, row < bindings.count else { return }

        if recordingRow == row {
            // Clicking Record again while recording that row → cancel
            cancelRecording()
        } else {
            beginRecording(row: row)
        }
    }

    // MARK: - Helpers

    /// Builds a human-readable shortcut string like "⌃⌥←" from an NSEvent.
    private func buildDisplayString(modifierFlags: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        var result = ""
        if modifierFlags.contains(.control) { result += "⌃" }
        if modifierFlags.contains(.option)  { result += "⌥" }
        if modifierFlags.contains(.shift)   { result += "⇧" }
        if modifierFlags.contains(.command) { result += "⌘" }
        result += keyCodeDisplayString(keyCode)
        return result
    }

    private func keyCodeDisplayString(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        case kVK_Return:     return "↩"
        case kVK_Tab:        return "⇥"
        case kVK_Delete:     return "⌫"
        case kVK_Space:      return "Space"
        case kVK_F1:  return "F1";  case kVK_F2:  return "F2"
        case kVK_F3:  return "F3";  case kVK_F4:  return "F4"
        case kVK_F5:  return "F5";  case kVK_F6:  return "F6"
        case kVK_F7:  return "F7";  case kVK_F8:  return "F8"
        case kVK_F9:  return "F9";  case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        default:
            // Use UCKeyTranslate to get the character for this key code
            if let char = characterForKeyCode(keyCode) {
                return char.uppercased()
            }
            return "(\(keyCode))"
        }
    }

    private func characterForKeyCode(_ keyCode: UInt16) -> String? {
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutDataRef = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }
        let layoutData = unsafeBitCast(layoutDataRef, to: CFData.self)
        let layoutPtr  = unsafeBitCast(CFDataGetBytePtr(layoutData), to: UnsafePointer<UCKeyboardLayout>.self)

        var deadKeyState: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var charsLength = 0

        let status = UCKeyTranslate(
            layoutPtr,
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysMask),
            &deadKeyState,
            4,
            &charsLength,
            &chars
        )
        guard status == noErr, charsLength > 0 else { return nil }
        return String(chars.prefix(charsLength).map { Character(Unicode.Scalar($0)!) })
    }
}

// MARK: - NSTableViewDataSource

extension ShortcutsViewController: NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        bindings.count
    }
}

// MARK: - NSTableViewDelegate

extension ShortcutsViewController: NSTableViewDelegate {

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn else { return nil }
        let binding = bindings[row]

        switch column.identifier {

        case Self.actionCellID:
            let cellID = Self.actionCellID
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView
            if cell == nil {
                let textField = makeLabel()
                let view = NSTableCellView()
                view.identifier = cellID
                view.addSubview(textField)
                view.textField = textField
                pinToCenter(textField, in: view)
                cell = view
            }
            cell?.textField?.stringValue = binding.zone.displayName
            return cell

        case Self.shortcutCellID:
            let cellID = Self.shortcutCellID
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? NSTableCellView
            if cell == nil {
                let textField = makeLabel()
                textField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
                let view = NSTableCellView()
                view.identifier = cellID
                view.addSubview(textField)
                view.textField = textField
                pinToCenter(textField, in: view)
                cell = view
            }
            // The shortcut column should always use monospaced font
            cell?.textField?.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            cell?.textField?.stringValue = binding.displayString
            return cell

        case Self.recordCellID:
            let cellID = Self.recordCellID
            var cell = tableView.makeView(withIdentifier: cellID, owner: self) as? RecordButtonCellView
            if cell == nil {
                let button = NSButton(title: "Record", target: self, action: #selector(recordButtonClicked(_:)))
                button.bezelStyle = .rounded
                button.setButtonType(.momentaryPushIn)
                button.translatesAutoresizingMaskIntoConstraints = false

                let view = RecordButtonCellView()
                view.identifier = cellID
                view.addSubview(button)
                view.button = button

                NSLayoutConstraint.activate([
                    button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
                    button.widthAnchor.constraint(equalToConstant: 84),
                ])
                cell = view
            }

            let isRecording = (recordingRow == row)
            cell?.button?.tag = row
            cell?.button?.title = isRecording ? "Press key…" : "Record"
            cell?.button?.highlight(isRecording)
            return cell

        default:
            return nil
        }
    }

    // MARK: - Cell helpers

    private func makeLabel() -> NSTextField {
        let tf = NSTextField(labelWithString: "")
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.isEditable = false
        tf.isBordered = false
        tf.backgroundColor = .clear
        tf.lineBreakMode = .byTruncatingTail
        return tf
    }

    private func pinToCenter(_ view: NSView, in container: NSView) {
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            view.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
    }
}

// MARK: - NSWindowDelegate

extension ShortcutsViewController: NSWindowDelegate {

    func windowWillClose(_ notification: Notification) {
        cancelRecording()
    }
}

// MARK: - RecordButtonCellView

/// A minimal NSTableCellView subclass that holds a reference to its button.
private final class RecordButtonCellView: NSTableCellView {
    var button: NSButton?
}
