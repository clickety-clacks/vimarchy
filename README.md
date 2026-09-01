# Vimarchy

<p align="center">
  <img src="assets/vimarchy-hero.webp" alt="Vimarchy window hints and swap mode in action" width="960">
</p>

Vimium-style window management UI for Omarchy.

Press a shortcut, see a large hint over every visible window, then use the
hints to focus, swap, or pair windows directly through Hyprland.

## Moves

| Gesture | Move | Result |
| --- | --- | --- |
| Tap a hint | **Focus** | Focus that window. |
| Double-tap a hint | **Focus action** | Run the action configured for the current layout. By default, `dwindle` and `scrolling` toggle a full working-area view, while `master` promotes the window to master. |
| Hold a hint, then tap another | **Swap** | Exchange the two windows' tiled positions. |
| Hold a hint, then hold another | **Pair** | In `dwindle`, make the two windows sibling tiles in the split tree. |
| `Escape` | **Cancel** | Dismiss Vimarchy without moving a window. |

Some examples:

- **Hold `A`, tap `S`** to swap windows `A` and `S`.
- **Hold `A`, hold `S`** to pair windows `A` and `S` in `dwindle`.

Pair currently works only in `dwindle` and creates sibling tiles, not a tabbed
window group. Holding a destination in another layout leaves move mode open so
you can still swap or cancel.

## Install

```bash
omarchy plugin add https://github.com/clickety-clacks/vimarchy --enable
```

Add the static modal map and launcher to `~/.config/hypr/bindings.lua`:

```lua
local vimarchy = os.getenv("HOME") .. "/.config/omarchy/plugins/vimarchy/bin"
local hint_keys = "asdfghjklqwertyuiopzxcvbnm"

local function vimarchy_escape_bindings()
  hl.bind("SUPER + comma", hl.dsp.exec_cmd(vimarchy .. "/settings"))
  hl.bind("ESCAPE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("ALT + SPACE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset"))
end

hl.define_submap("vimarchy", function()
  for slot = 1, #hint_keys do
    local letter = hint_keys:sub(slot, slot)
    hl.bind(letter, hl.dsp.exec_cmd(vimarchy .. "/press " .. letter))
    hl.bind(letter, hl.dsp.exec_cmd(vimarchy .. "/release " .. letter), { release = true })
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
      local hint = first_letter .. second_letter
      hl.bind(second_letter, hl.dsp.exec_cmd(vimarchy .. "/press " .. hint))
      hl.bind(second_letter, hl.dsp.exec_cmd(vimarchy .. "/release " .. hint), { release = true })
    end
    vimarchy_escape_bindings()
  end)
end

hl.define_submap("vimarchy-swap", function()
  for slot = 1, #hint_keys do
    local letter = hint_keys:sub(slot, slot)
    hl.bind(letter, hl.dsp.exec_cmd(vimarchy .. "/swap-press " .. letter))
    hl.bind(letter, hl.dsp.exec_cmd(vimarchy .. "/swap-release " .. letter), { release = true })
  end
  vimarchy_escape_bindings()
end)

hl.define_submap("vimarchy-swap-double", function()
  for first = 1, #hint_keys do
    local letter = hint_keys:sub(first, first)
    hl.bind(letter, hl.dsp.submap("vimarchy-swap-" .. letter))
  end
  vimarchy_escape_bindings()
end)

for first = 1, #hint_keys do
  local first_letter = hint_keys:sub(first, first)
  hl.define_submap("vimarchy-swap-" .. first_letter, function()
    for second = 1, #hint_keys do
      local second_letter = hint_keys:sub(second, second)
      local hint = first_letter .. second_letter
      hl.bind(second_letter, hl.dsp.exec_cmd(vimarchy .. "/swap-press " .. hint))
      hl.bind(second_letter, hl.dsp.exec_cmd(vimarchy .. "/swap-release " .. hint), { release = true })
    end
    vimarchy_escape_bindings()
  end)
end

-- After a normal selection, only a quick repeat of that hint's final letter is
-- intercepted. Every other key continues to the newly focused application.
for slot = 1, #hint_keys do
  local letter = hint_keys:sub(slot, slot)
  hl.define_submap("vimarchy-double-tap-" .. letter, function()
    hl.bind(letter, hl.dsp.exec_cmd(vimarchy .. "/double-tap " .. letter))
    hl.bind("ESCAPE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
    hl.bind("ALT + SPACE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
    hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset"))
  end)
end

hl.define_submap("vimarchy-settings", function()
  hl.bind("ESCAPE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("ALT + SPACE", hl.dsp.exec_cmd(vimarchy .. "/cancel"))
  hl.bind("SUPER + ESCAPE", hl.dsp.submap("reset"))
end)

o.bind("ALT + SPACE", "Vimarchy window hints", vimarchy .. "/open")
```

Hyprland reloads the binding automatically. Validate it with:

```bash
hyprctl reload
hyprctl configerrors
```

## Behavior

- Prioritizes home-row letters: `a s d f g h j k l`, then the remaining letters.
- Opens settings from the active hint map with `Super+,`.
- Tries to keep the same letter assigned to a window for better referential
  stability.
- Holding a hint for 350 ms enters move mode.
- In move mode, tapping a destination swaps it with the source. Holding a
  destination for 350 ms on a `dwindle` workspace reparents the source and
  destination as sibling tiles. Their side follows the source window's current
  position relative to the destination. Holding a destination in any other
  layout does nothing and leaves move mode active.
- Double-tapping a hint focuses it and runs a layout-specific action.
  `dwindle` and `scrolling` toggle a maximized working-area view that keeps the
  bar visible; `master` promotes the window and does nothing if it is already
  master.
- Press Escape to cancel.

## Double-tap actions

Vimarchy reads optional double-tap configuration from
`~/.config/omarchy/vimarchy.json`. Omitted layouts retain their defaults. A
layout can select a built-in action, be disabled, or invoke a command directly:

```json
{
  "doubleTap": {
    "timeoutMs": 280,
    "layouts": {
      "dwindle": "toggle-maximized",
      "scrolling": ["my-scrolling-focus-script"],
      "master": "promote-master",
      "custom-layout": {
        "command": ["sh", "-lc", "do-something-with $VIMARCHY_WINDOW_ADDRESS"]
      }
    }
  }
}
```

Built-ins are `toggle-maximized`, `promote-master`, and `disabled`. Callback
commands run without an implicit shell and receive `VIMARCHY_LAYOUT`,
`VIMARCHY_WINDOW_ADDRESS`, `VIMARCHY_WINDOW_STABLE_ID`,
`VIMARCHY_WORKSPACE_ID`, `VIMARCHY_FULLSCREEN_STATE`, and `VIMARCHY_HINT`.
Use an explicit `sh -lc` argv as above only when shell syntax is wanted. See
[`vimarchy.example.json`](vimarchy.example.json) for the complete defaults.
`timeoutMs` is measured from the first key-down to the second key-down,
defaults to 280 ms, and is clamped to the supported 120–600 ms range.

## Keyboard safety

Vimarchy's layer surface is input-passive: it never grabs the Wayland
keyboard. Static Hyprland submaps distinguish release taps from long presses,
route swap destinations, and briefly capture only the selected hint's final
letter for double-tap detection. A first-press candidate also recognizes a
second key-down that arrives before release IPC has installed that transient
map. Other typing remains unbound. Normal bindings are never removed or
rewritten. `Super+Escape` always resets the submap before asking the overlay to
close, even if the plugin is broken or missing.

## Requirements

- Omarchy Quattro
- Hyprland
- Omarchy Shell / Quickshell
- `hyprctl` and `jq` (included with Omarchy)

## Status

Beta quality.
