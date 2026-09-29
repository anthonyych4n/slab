# Slab

Windows 11-style snap layouts for macOS: drag, snap, and tile your windows from the menu bar.

## Why

Windows has had great window snapping for years: drag to an edge, pick a layout, fill the rest of the screen in a couple of clicks. macOS's built-in tiling is limited by comparison. Slab is a small native menu bar app that brings that workflow to the Mac.

## Features

- **Drag-to-snap.** Drag a window by its title bar to a screen edge or corner and a frosted-glass preview shows where it will land.
  - Left / right edge: half screen
  - Corners: quarter screen
  - Top edge: maximize (top half on portrait displays)
  - Bottom edge is intentionally ignored so you don't snap by brushing the Dock
- **Layout flyout.** While you're dragging at the left, right, or top edge, a chooser slides out with six layouts (halves, top/bottom, 2x2 grid, three columns, main + sidebar, full screen). Drop the window onto any zone.
- **Snap Assist.** After you snap a window, Slab offers to fill the remaining zones of that layout with your other open windows.
- **Layout Picker** (`⌃⌥L`). Choose from 12 built-in layouts plus your own and assign windows to each zone.
- **Custom layouts.** Visual editor with draggable, resizable zones and exact X/Y/W/H percentage fields.
- **Snap groups.** Windows snapped within a few seconds of each other form a group. "Restore Last Snap Group" puts them all back.
- **Unsnap.** Put a window back to its size and position from before it was snapped.
- **Multi-monitor aware.** Edges shared with another display don't trigger snaps, so moving windows between screens works as usual.
- **Customizable shortcuts.** Every shortcut can be rebound in Preferences, and "Reset to Defaults" restores them.
- **Preferences:** snap-on-drag toggle, hot zone size, launch at login, and JSON config import/export.

## Keyboard shortcuts

Defaults (all rebindable in Preferences > Hotkeys):

| Action | Shortcut |
| --- | --- |
| Snap left / right half | `⌃⌥←` / `⌃⌥→` |
| Snap top / bottom half | `⌃⌥↑` / `⌃⌥↓` |
| Top-left / top-right quarter | `⌃⌥` Keypad 7 / Keypad 9 |
| Bottom-left / bottom-right quarter | `⌃⌥` Keypad 1 / Keypad 3 |
| Full screen (non-native) | `⌃⌥↩` |
| Open Layout Picker | `⌃⌥L` |
| Unsnap | `⌃⌥Z` |
| Restore last snap group | `⌃⌥G` |

## Built-in layouts

Left | Right, ⅓ | ⅔, ⅔ | ⅓, 30 | 70, 70 | 30, Top | Bottom, Three Columns, Main + Sidebar, Main + 2, 2 + Main, 2x2 Grid, Full Screen.

## Requirements

- macOS 13 Ventura or later
- **Accessibility permission.** Slab moves and resizes other apps' windows through the Accessibility API. On first launch, macOS will ask you to allow it in **System Settings > Privacy & Security > Accessibility**. Drag-to-snap and shortcuts won't work until it's granted.

## Build from source

Slab uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode project, so `Slab.xcodeproj` isn't checked in.

```bash
brew install xcodegen
git clone https://github.com/anthonyych4n/slab.git
cd slab
xcodegen generate
open Slab.xcodeproj
```

Then build and run the **Slab** scheme (Xcode 15+). Swift Package Manager fetches the one dependency, [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts), on the first build. Pick your own signing team under Signing & Capabilities if Xcode asks for one.

Slab runs as a menu bar app (no Dock icon). Look for the split-rectangle icon in the menu bar.

Unit tests live in the `SlabTests` target.

## Tech stack

- Swift 5.9, AppKit for the menu bar, overlays, and event handling, SwiftUI for Preferences, the picker, and the layout editor
- Accessibility API (`AXUIElement`) to move and resize windows
- `CGWindowListCopyWindowInfo` to find windows, `NSEvent` global monitors to detect drags
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) for global hotkeys and the shortcut recorder
- `SMAppService` for launch at login, `UserDefaults` and JSON for settings
- XcodeGen for project generation

## Project layout

```
App/        App delegate, menu bar, onboarding, permission check
Core/       Window enumeration and snapping, drag detection, screens, snap groups
Overlay/    Snap preview, edge flyout, Snap Assist, Layout Picker
Layouts/    Layout model, built-in and custom layouts
Settings/   Preferences UI, hotkeys, custom layout editor, defaults
Tests/      Unit tests
```

## License

No license has been chosen yet. All rights reserved by the author until one is added.
