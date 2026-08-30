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
local hint_keys = "asdfghjklqwertyuiopzxcvbnm"

local function vimarchy_escape_bindings()
  hl.bind("ESCAPE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("ALT + SPACE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset"))
end

hl.define_submap("vimarchy", function()
  for slot = 1, #hint_keys do
    local letter = hint_keys:sub(slot, slot)
    hl.bind(letter, hl.dsp.exec_cmd(vimarchy .. "/select " .. letter))
  end
  vimarchy_escape_bindings()
end)

hl.define_submap("vimarchy-double", function()
  for first = 1, #hint_keys do
    local letter = hint_keys:sub(first, first)
    hl.bind(letter, hl.dsp.submap("vimarchy-" .. letter))
  end
  vimarchy_escape_bindings()
end)

for first = 1, #hint_keys do
  local first_letter = hint_keys:sub(first, first)
  hl.define_submap("vimarchy-" .. first_letter, function()
    for second = 1, #hint_keys do
      local second_letter = hint_keys:sub(second, second)
      hl.bind(second_letter, hl.dsp.exec_cmd(vimarchy .. "/select " .. first_letter .. second_letter))
    end
    vimarchy_escape_bindings()
  end)
end

o.bind("ALT + SPACE", "Vimarchy window hints", vimarchy .. "/open")
hl.unbind("SUPER + comma")
o.bind("h", "Vimarchy opacity", "omarchy-shell shell toggle vimarchy '{\"mode\":\"settings\"}'")
```

Hyprland reloads the binding automatically. Validate it with:

```bash
hyprctl reload
hyprctl configerrors
```

## Behavior

- Shows only mapped windows on the workspaces currently visible across outputs.
- Includes visible special-workspace and pinned windows.
- Prioritizes home-row letters: `a s d f g h j k l`, then the remaining letters.
- Uses one-letter hints for up to 26 windows. Above that, all hints become
  unambiguous two-letter sequences such as `aa`, `as`, and `ad`.
- Remembers assignments by Hyprland stable window ID, including windows on
  other workspaces. A letter is reused only after its window closes.
- Supports multiple outputs and fractional scaling.
- Press Escape to cancel.

## Keyboard safety

Vimarchy's layer surface is input-passive: it never grabs the Wayland
keyboard. Static Hyprland submaps temporarily route only hint letters, Escape,
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
