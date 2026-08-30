# Vimarchy

Vimium-style window hints for Omarchy, inspired by tmux `display-panes`.

Press a shortcut, see a large hint over every visible window, then type a hint
to focus that window. Vimarchy does not rearrange, resize, or preview windows.

## Install

```bash
omarchy plugin add https://github.com/leftspin/vimarchy --enable
```

Add a keybinding to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + Q", "Vimarchy window hints", "omarchy-shell shell toggle vimarchy '{}'")
```

Hyprland reloads the binding automatically. Validate it with:

```bash
hyprctl reload
hyprctl configerrors
```

## Behavior

- Shows only mapped windows on the workspaces currently visible across outputs.
- Includes visible special-workspace and pinned windows.
- Uses `1`–`9` first, followed by home-row-oriented letter hints.
- Supports multiple outputs and fractional scaling.
- Press Escape to cancel.

## Requirements

- Omarchy Quattro
- Hyprland
- Omarchy Shell / Quickshell
- `hyprctl` and `jq` (included with Omarchy)

## Status

Early spike. The core behavior works, but visual and multi-output edge cases
still need broader testing.
