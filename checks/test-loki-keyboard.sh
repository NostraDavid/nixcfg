#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
nix eval --impure --json --file "$root/checks/loki-keyboard.nix" checks >/dev/null
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
LOKI_KEYBOARD_FIXTURE="$tmp" nix eval --impure --raw --file "$root/checks/loki-keyboard.nix" fixture >"$tmp/remove.sh"
export TRACE="$tmp/trace"
mkdir -p "$tmp/brew/bin" "$tmp/brew/Caskroom" "$tmp/support/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall"
cat >"$tmp/sudo" <<'STUB'
#!/usr/bin/env bash
set -eu
[[ "$1 $2 $3" == "-H -u fixture" ]]
shift 3
case "$1" in
/bin/bash) shift; exec bash "$@" ;;
/usr/bin/env) shift; exec env "$@" ;;
esac
exec "$@"
STUB
cat >"$tmp/brew/bin/brew" <<'STUB'
#!/usr/bin/env bash
set -eu
[[ "$*" == "uninstall --cask karabiner-elements" && "$HOMEBREW_NO_AUTOREMOVE" == 1 ]]
echo brew >>"$TRACE"
rmdir "${0%/bin/brew}/Caskroom/karabiner-elements"
STUB
driver="$tmp/support/Karabiner-DriverKit-VirtualHIDDevice/scripts/uninstall/deactivate_driver.sh"
printf '%s\n' 'echo driver >>"$TRACE"' 'exit "${DRIVER_STATUS:-0}"' >"$driver"
chmod +x "$tmp/sudo" "$tmp/brew/bin/brew"
bash "$tmp/remove.sh"
test ! -e "$TRACE"
mkdir "$tmp/brew/Caskroom/karabiner-elements" "$tmp/brew/Caskroom/alfred"
if DRIVER_STATUS=3 bash "$tmp/remove.sh"; then exit 1; fi
[[ $(cat "$TRACE") == driver ]]
: >"$TRACE"
bash "$tmp/remove.sh"
bash "$tmp/remove.sh"
[[ $(cat "$TRACE") == $'driver\nbrew' && -d "$tmp/brew/Caskroom/alfred" ]]

node --input-type=module - "$root" <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const dir = `${process.argv[2]}/dotfiles/vscode-1.106.2/.config/Code/User`;
const bindings = JSON.parse(readFileSync(`${dir}/keybindings.json`, "utf8").replace(/^\/\/[^\n]*\n/, ""));
const settings = JSON.parse(readFileSync(`${dir}/settings.json`, "utf8"));
assert.equal(settings["terminal.integrated.sendKeybindingsToShell"], false);
for (const key of ["ctrl+v", "ctrl+shift+v"]) {
    const binding = bindings.find(binding => binding.key === key && binding.when === "terminalFocus");
    assert.equal(binding?.command, "workbench.action.terminal.paste");
}
const terminal = bindings.filter(binding => binding.when === "isMac && terminalFocus");
assert.equal(terminal.length, 4);
assert.equal(terminal.find(binding => binding.key === "cmd+c").args.text, "\u0003");
assert.equal(terminal.find(binding => binding.key === "cmd+v").command, "workbench.action.terminal.paste");
assert.equal(terminal.find(binding => binding.key === "cmd+shift+c").command, "workbench.action.terminal.copySelection");
assert.equal(terminal.find(binding => binding.key === "cmd+shift+v").command, "workbench.action.terminal.paste");
JS
echo 'Loki keyboard configuration and terminal shortcut checks passed.'
