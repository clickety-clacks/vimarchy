# Vimarchy

Vimium-style window hints for Omarchy, inspired by tmux `display-panes`.

Press a shortcut, see a large hint over every visible window, then type a hint
to focus that window. Vimarchy does not rearrange, resize, or preview windows.

## Install

```bash
omarchy plugin add https://github.com/leftspin/vimarchy --enable
```

Add the static modal map and launcher to `~/.config/hypr/bindings.lua`:

```lua
local vimarchy = os.getenv("HOME") .. "/.config/omarchy/plugins/vimarchy/bin"

hl.define_submap("vimarchy", function()
  for slot = 1, 9 do
    hl.bind(tostring(slot), hl.dsp.exec_cmd(vimarchy .. "/select " .. slot))
  end
  hl.bind("ESCAPE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("SUPER + Q", hl.dsp.exec_cmd(vimarchy .. "/cancel"), { release = true })
  hl.bind("SUPER + ESCAPE", function()
    hl.dispatch(hl.dsp.submap("reset"))
    hl.dispatch(hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  end)
end)

o.bind("SUPER + Q", "Vimarchy window hints", vimarchy .. "/open", { release = true })
```

Hyprland reloads the binding automatically. Validate it with:

```bash
hyprctl reload
hyprctl configerrors
```

## Behavior

- Shows only mapped windows on the workspaces currently visible across outputs.
- Includes visible special-workspace and pinned windows.
- Uses `1`–`9` for direct selection.
- Supports multiple outputs and fractional scaling.
- Press Escape to cancel.

## Keyboard safety

Vimarchy's layer surface is input-passive: it never grabs the Wayland
keyboard. A static Hyprland submap temporarily routes only `1`–`9`, Escape,
and the Vimarchy toggle while the hints are visible. Normal bindings are never
removed or rewritten. `Super+Escape` always resets the submap before asking
the overlay to close, even if the plugin is broken or missing.

## Requirements

- Omarchy Quattro
- Hyprland
- Omarchy Shell / Quickshell
- `hyprctl` and `jq` (included with Omarchy)

## Status

Early spike. The core behavior works, but visual and multi-output edge cases
still need broader testing.
