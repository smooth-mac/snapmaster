import Carbon.HIToolbox
import AppKit

final class HotkeyManager {

    // MARK: - Public State

    /// Current bindings. Assigning a new value automatically re-registers all hotkeys.
    var bindings: [HotkeyBinding] {
        didSet { reregisterAll() }
    }

    // MARK: - Private State

    /// Maps binding id → registered Carbon EventHotKeyRef.
    private var hotKeyRefs: [Int: EventHotKeyRef] = [:]

    /// The installed Carbon event handler reference.
    private var eventHandlerRef: EventHandlerRef?

    /// UserDefaults key for persisting bindings.
    private static let userDefaultsKey = "HotkeyBindings"

    // MARK: - Init

    init() {
        // Attempt to restore persisted bindings; fall back to built-in defaults.
        if let data = UserDefaults.standard.data(forKey: HotkeyManager.userDefaultsKey),
           let decoded = try? JSONDecoder().decode([HotkeyBinding].self, from: data) {
            bindings = decoded
        } else {
            bindings = HotkeyBinding.defaults
        }
    }

    // MARK: - Lifecycle

    /// Install the Carbon event handler and register all hotkeys.
    func start() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind:  UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            HotkeyManager.carbonCallback,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        for binding in bindings {
            registerHotkey(binding)
        }
    }

    /// Unregister all hotkeys and remove the Carbon event handler.
    func stop() {
        unregisterAll()

        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    // MARK: - Public Mutation

    /// Replace one binding (matched by id) and persist the updated list.
    func rebind(_ newBinding: HotkeyBinding) {
        if let index = bindings.firstIndex(where: { $0.id == newBinding.id }) {
            bindings[index] = newBinding   // triggers didSet → reregisterAll → persistBindings
        } else {
            bindings.append(newBinding)    // triggers didSet → reregisterAll → persistBindings
        }
    }

    /// Restore factory defaults and persist.
    func resetDefaults() {
        bindings = HotkeyBinding.defaults  // triggers didSet → reregisterAll → persistBindings
    }

    // MARK: - Carbon Event Callback

    /// C-compatible static callback; routes the event back to the owning HotkeyManager.
    private static let carbonCallback: EventHandlerProcPtr = {
        (nextHandler, theEvent, userData) -> OSStatus in
        guard let userData = userData else { return OSStatus(eventNotHandledErr) }
        let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
        manager.handleCarbonEvent(theEvent)
        return noErr
    }

    // MARK: - Event Handling

    private func handleCarbonEvent(_ event: EventRef?) {
        var hkID = EventHotKeyID()
        GetEventParameter(
            event,
            UInt32(kEventParamDirectObject),
            UInt32(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hkID
        )

        guard let binding = bindings.first(where: { $0.id == Int(hkID.id) }) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.performSnap(zone: binding.zone)
        }
    }

    // MARK: - Snapping

    private func performSnap(zone: SnapZone) {
        guard let window = WindowController.getFrontmostWindow() else { return }

        // Use the screen that contains the mouse cursor.
        let cursor = NSEvent.mouseLocation   // AppKit coords (bottom-left origin)
        let screen = NSScreen.screens.first { NSPointInRect(cursor, $0.frame) }
                     ?? NSScreen.main
                     ?? NSScreen.screens[0]

        let frame = zone.targetFrame(screen: screen)
        WindowController.setFrame(frame, for: window)

        print("[HotkeyManager] Snapped '\(zone.displayName)' on \(screen.localizedName)")
    }

    // MARK: - Registration Helpers

    private func registerHotkey(_ binding: HotkeyBinding) {
        var ref: EventHotKeyRef?
        var hkID = EventHotKeyID()
        hkID.signature = fourCharCode("SNPM")
        hkID.id        = UInt32(binding.id)

        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.carbonModifiers,
            hkID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        if status == noErr, let ref = ref {
            hotKeyRefs[binding.id] = ref
        } else {
            print("[HotkeyManager] Failed to register '\(binding.displayString)' (id \(binding.id)): OSStatus \(status)")
        }
    }

    private func unregisterAll() {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
    }

    private func reregisterAll() {
        unregisterAll()
        for binding in bindings {
            registerHotkey(binding)
        }
        persistBindings()
    }

    // MARK: - Persistence

    private func persistBindings() {
        if let data = try? JSONEncoder().encode(bindings) {
            UserDefaults.standard.set(data, forKey: HotkeyManager.userDefaultsKey)
        }
    }
}

// MARK: - FourCharCode Helper

/// Packs the first four UTF-8 bytes of a string into a FourCharCode (UInt32).
private func fourCharCode(_ s: String) -> FourCharCode {
    s.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
}
