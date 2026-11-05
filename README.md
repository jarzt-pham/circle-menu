# CircleMenu

macOS menu-bar app: **hold Left + Right mouse buttons** to open a radial menu at the cursor.
Move toward a slice, release to run it. Release in the center to cancel.

Options act on the current **Finder selection** (fallback: front Finder window folder, then Desktop).
Defaults: **VS Code**, **Terminal** (opens the containing folder), **Copy Path**.

## Settings

Menu-bar icon → **Settings…** (⌘,), or open the app again while it's running.

- **Menu**: live preview, add/remove (max 8), drag to reorder, edit title, SF Symbol icon and action:
  - *Open with Application* (optionally the containing folder)
  - *Copy Path*
  - *Run Shell Command* (zsh; selected paths are `"$@"`)
- **General**: enable/disable, launch at login, chord delay, permission status, reset.

Config is stored in `~/Library/Application Support/CircleMenu/config.json`.

## Build & run

```bash
./build.sh
open build/CircleMenu.app
```

First run asks for:
1. **Accessibility** (System Settings → Privacy & Security → Accessibility) — needed to read mouse buttons.
2. **Automation → Finder** — asked on first action, needed to read the Finder selection.

After rebuilding, if the chord stops working, remove and re-add CircleMenu in Accessibility.

Tip: to start on login, add `build/CircleMenu.app` in System Settings → General → Login Items.

## Notes

A first button-down is delayed by the chord delay (default 150 ms) to detect the chord;
normal clicks/drags are replayed afterwards.
