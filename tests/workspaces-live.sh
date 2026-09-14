#!/usr/bin/env bash
# Opt-in compositor integration test. Run on a test desktop, never a daily driver.
# Exercises the scripts invoked by the bindings; does not simulate physical keys.
set -euo pipefail
[[ ${VIMARCHY_TEST_DESKTOP:-} == 1 ]] || { echo 'Set VIMARCHY_TEST_DESKTOP=1 on a test desktop.' >&2; exit 2; }
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$plugin_dir"
state_dir=$XDG_RUNTIME_DIR/vimarchy
original_focus=$(hyprctl -j activewindow | jq -r '.address // empty')
original_workspace=$(hyprctl -j activeworkspace | jq -r '.name')
[[ $original_workspace =~ ^[1-9]$|^10$ ]] || exit 2
scratch_open=$(hyprctl -j monitors | jq 'any(.[]; .specialWorkspace.id != 0)')
[[ $scratch_open == false ]] || { echo 'Close special workspaces first.' >&2; exit 2; }
test_pid=''
cleanup() {
  bin/cancel
  if hyprctl -j monitors | jq -e 'any(.[]; .specialWorkspace.name == "special:scratchpad")' >/dev/null; then
    hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratchpad")' >/dev/null
  fi
  [[ -z $test_pid ]] || kill "$test_pid" 2>/dev/null || true
  if [[ $original_focus =~ ^0x[0-9a-fA-F]+$ ]]; then
    hyprctl dispatch "hl.dsp.focus({window=\"address:$original_focus\"})" >/dev/null || true
  fi
}
trap cleanup EXIT
foot --app-id=vimarchy-workspace-test --title='Vimarchy workspace test' sleep 120 >/dev/null 2>&1 &
test_pid=$!
sleep 0.5
address=$(hyprctl -j clients | jq -r '.[] | select(.class == "vimarchy-workspace-test") | .address')
[[ $address =~ ^0x[0-9a-fA-F]+$ ]]
workspace() { hyprctl -j clients | jq -r --arg address "$address" '.[] | select(.address == $address) | .workspace.name'; }
open_hint() {
  bin/open
  hint=$(jq -r --arg address "$address" '.windows[] | select(.address == $address) | .hint' "$state_dir/snapshot.json")
  [[ $hint =~ ^[a-z]{1,2}$ ]]
}
hold_alt() {
  bin/press "$hint" alt
  sleep 0.65
  [[ $(hyprctl submap | tr -d '\n') == vimarchy-workspaces ]]
  bin/release "$hint"
  [[ $(hyprctl submap | tr -d '\n') == vimarchy-workspaces ]]
}
open_hint
hold_alt
current_key=$original_workspace
[[ $current_key != 10 ]] || current_key=0
bin/workspace-select "$current_key"
[[ $(workspace) == "$original_workspace" ]]
[[ $(hyprctl submap | tr -d '\n') == vimarchy-workspaces ]]
bin/workspace-select s alt
[[ $(workspace) == special:scratchpad ]]
[[ $(hyprctl -j activeworkspace | jq -r '.name') == "$original_workspace" ]]
hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratchpad")' >/dev/null
sleep 0.3
open_hint
hold_alt
bin/workspace-select s
[[ $(hyprctl submap | tr -d '\n') == vimarchy-workspaces ]]
bin/workspace-select 0 alt
[[ $(workspace) == 10 ]]
if hyprctl -j monitors | jq -e 'any(.[]; .specialWorkspace.name == "special:scratchpad")' >/dev/null; then
  hyprctl dispatch 'hl.dsp.workspace.toggle_special("scratchpad")' >/dev/null
fi
hyprctl dispatch "hl.dsp.window.move({workspace=\"$original_workspace\",follow=false,window=\"address:$address\"})" >/dev/null
sleep 0.2
# Plain destination taps follow and focus, including into/out of scratchpad.
open_hint
hold_alt
bin/workspace-select s
sleep 0.2
[[ $(workspace) == special:scratchpad ]]
hyprctl -j monitors | jq -e 'any(.[]; .specialWorkspace.name == "special:scratchpad")' >/dev/null
[[ $(hyprctl -j activewindow | jq -r '.address') == "$address" ]]
open_hint
hold_alt
bin/workspace-select 0
sleep 0.2
[[ $(workspace) == 10 ]]
[[ $(hyprctl -j activeworkspace | jq -r '.name') == 10 ]]
[[ $(hyprctl -j activewindow | jq -r '.address') == "$address" ]]
open_hint
hold_alt
bin/workspace-select "$current_key"
sleep 0.2
[[ $(hyprctl -j activeworkspace | jq -r '.name') == "$original_workspace" ]]
open_hint
bin/press "$hint"
sleep 0.65
[[ $(hyprctl submap | tr -d '\n') == vimarchy-swap ]]
bin/cancel
[[ $(workspace) == "$original_workspace" ]]
# Alt double-tap remains independent of the new hold action.
for expected in 1 0; do
  open_hint
  bin/press "$hint" alt
  bin/release "$hint"
  bin/double-tap "${hint: -1}" alt
  sleep 0.6
  [[ $(hyprctl -j clients | jq -r --arg address "$address" '.[] | select(.address == $address) | .fullscreen') == "$expected" ]]
done
echo 'PASS: Alt hold/release, current-workspace exclusion, scratchpad round trip, 0→10, plain tap follows, Alt tap stays, normal hold, Alt double-tap toggle.'
