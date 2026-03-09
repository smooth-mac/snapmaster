import Carbon.HIToolbox
import AppKit

struct HotkeyBinding: Codable, Equatable {

    // MARK: - Properties

    /// Unique identifier (1–11), used as the Carbon EventHotKeyID.id.
    let id: Int

    /// The snap zone this binding triggers.
    var zone: SnapZone

    /// Carbon / macOS virtual key code.
    var keyCode: UInt32

    /// Carbon modifier flags (controlKey, optionKey, shiftKey, cmdKey).
    var carbonModifiers: UInt32

    // MARK: - Display String

    /// Human-readable shortcut string, e.g. "⌃⌥←".
    /// Modifier symbols are ordered: ⌃ ⌥ ⇧ ⌘, followed by the key symbol.
    var displayString: String {
        var result = ""

        // Carbon modifier constants:
        //   controlKey = 4096  (0x1000)
        //   optionKey  = 2048  (0x0800)
        //   shiftKey   =  512  (0x0200)
        //   cmdKey     =  256  (0x0100)
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { result += "⌘" }

        let keyName = HotkeyBinding.keyNames[keyCode] ?? "[\(keyCode)]"
        result += keyName

        return result
    }

    // MARK: - Key Name Lookup Table

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_LeftArrow):  "←",
        UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow):    "↑",
        UInt32(kVK_DownArrow):  "↓",
        UInt32(kVK_Return):     "↩",
        UInt32(kVK_Tab):        "⇥",
        UInt32(kVK_Space):      "Space",
        UInt32(kVK_Delete):     "⌫",
        UInt32(kVK_Escape):     "⎋",
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
    ]

    // MARK: - Modifier Conversion

    /// Convert NSEvent modifier flags to Carbon modifier flags.
    static func carbonModifiers(from nsModifiers: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if nsModifiers.contains(.control) { carbon |= UInt32(controlKey) }
        if nsModifiers.contains(.option)  { carbon |= UInt32(optionKey)  }
        if nsModifiers.contains(.shift)   { carbon |= UInt32(shiftKey)   }
        if nsModifiers.contains(.command) { carbon |= UInt32(cmdKey)     }
        return carbon
    }

    // MARK: - Key Code Conversion

    /// Convert an NSEvent key code (UInt16) to a Carbon key code (UInt32).
    /// The virtual key codes are identical between NSEvent and Carbon on macOS,
    /// so this is a straightforward widening cast.
    static func carbonKeyCode(from nsKeyCode: UInt16) -> UInt32 {
        return UInt32(nsKeyCode)
    }

    // MARK: - Default Bindings

    /// Rectangle-style default hotkey bindings.
    static var defaults: [HotkeyBinding] {
        let ctrlOpt = UInt32(controlKey) | UInt32(optionKey)
        return [
            // Halves — arrow keys
            HotkeyBinding(id: 1, zone: .left,        keyCode: UInt32(kVK_LeftArrow),  carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 2, zone: .right,       keyCode: UInt32(kVK_RightArrow), carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 3, zone: .top,         keyCode: UInt32(kVK_UpArrow),    carbonModifiers: ctrlOpt),
            // Quarters — UIJK cluster (mirrors arrow key layout)
            HotkeyBinding(id: 4, zone: .topLeft,     keyCode: UInt32(kVK_ANSI_U),     carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 5, zone: .topRight,    keyCode: UInt32(kVK_ANSI_I),     carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 6, zone: .bottomLeft,  keyCode: UInt32(kVK_ANSI_J),     carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 7, zone: .bottomRight, keyCode: UInt32(kVK_ANSI_K),     carbonModifiers: ctrlOpt),
            // Bottom half — ↓ mirrors ↑ (maximize)
            HotkeyBinding(id: 8,  zone: .bottom,       keyCode: UInt32(kVK_DownArrow),  carbonModifiers: ctrlOpt),
            // Thirds — DFG cluster (adjacent keys, left-to-right order)
            HotkeyBinding(id: 9,  zone: .leftThird,    keyCode: UInt32(kVK_ANSI_D),     carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 10, zone: .centerThird,  keyCode: UInt32(kVK_ANSI_F),     carbonModifiers: ctrlOpt),
            HotkeyBinding(id: 11, zone: .rightThird,   keyCode: UInt32(kVK_ANSI_G),     carbonModifiers: ctrlOpt),
        ]
    }
}
