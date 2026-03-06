# SnapMaster

macOS window snapping utility. Drag any window to a screen edge to snap it to that zone — like Windows Snap or the Magnet/Rectangle apps.

## Snap zones

```
┌──────────────────────────────┐
│         ↑ top (maximize)      │
├─────────┬────────────────────┤
│ ←  left │        right  →    │
│   1/2   │        1/2         │
├────┬────┴──────────────┬────┤
│↙ BL│                   │BR ↘│
│ 1/4│                   │1/4 │
└────┴───────────────────┴────┘
  TL (top-left corner)  TR (top-right corner)
```

| Drag to            | Result            |
|--------------------|-------------------|
| Left edge          | Left half         |
| Right edge         | Right half        |
| Top edge (center)  | Maximize          |
| Top-left corner    | Top-left quarter  |
| Top-right corner   | Top-right quarter |
| Bottom-left corner | Bottom-left quarter |
| Bottom-right corner| Bottom-right quarter |

## Requirements

- macOS 13 Ventura or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Build

### 1. Install XcodeGen

```bash
brew install xcodegen
```

### 2. Generate Xcode project

```bash
cd ~/SnapMaster
xcodegen generate
```

### 3. Open in Xcode and build

```bash
open SnapMaster.xcodeproj
```

Or build from terminal:
```bash
xcodebuild -project SnapMaster.xcodeproj \
           -scheme SnapMaster \
           -configuration Release \
           build
```

## First launch — Accessibility permission

On first launch, SnapMaster will prompt you to grant **Accessibility** permission.

1. Click **Open Settings**
2. Go to **System Settings → Privacy & Security → Accessibility**
3. Enable **SnapMaster**
4. Restart SnapMaster

Without this permission, CGEventTap and AXUIElement cannot access other apps' windows.

## Architecture

```
AppDelegate          ← @main, wires all components together
├── MenuBarManager   ← NSStatusItem, enable/disable toggle
├── EventMonitor     ← CGEventTap (global mouse events)
│   └── SnapZoneDetector ← CGPoint → SnapZone mapping
├── OverlayWindowManager ← translucent preview while dragging
└── WindowController ← AXUIElement read/write (position + size)
```

### Key design decisions

| Decision | Reason |
|----------|--------|
| No sandbox | CGEventTap + AXUIElement require unrestricted process access |
| Direct distribution (Developer ID) | App Store blocks non-sandboxed apps |
| mouseUp trigger | Avoids moving windows mid-drag; only snaps on release |
| visibleFrame for zones | Respects menu bar and Dock height automatically |
| AX position set before size | Required order by the Accessibility API |

## Coordinate systems

```
NSScreen.frame      → bottom-left origin, Y up  (AppKit)
CGEvent.location    → top-left origin,    Y down (Core Graphics)
AXUIElement pos     → top-left origin,    Y down (same as CG)

Conversion (NS → CG):
  cgY = primaryScreenHeight - nsRect.maxY

Conversion (CG → NS):
  nsY = primaryScreenHeight - cgY - height
```

## Distribution

Build with **Developer ID Application** certificate and notarize with `notarytool`.
Do NOT submit to the App Store — sandbox requirement is incompatible.
