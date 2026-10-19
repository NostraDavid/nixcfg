#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fixture_home="$tmp/home"
mkdir -p "$fixture_home/.config/karabiner"
target="$fixture_home/.config/karabiner/karabiner.json"

# Build the real module with Linux tools so its file migration can run here.
nix build --impure --file "$root/checks/loki-keyboard.nix" \
    --argstr fixtureHome "$fixture_home" fixture.activationPackage --no-link
nix eval --impure --json --file "$root/checks/loki-keyboard.nix" \
    --argstr fixtureHome "$fixture_home" checks
nix eval --impure --raw --file "$root/checks/loki-keyboard.nix" \
    --argstr fixtureHome "$fixture_home" activation >"$tmp/activate.sh"

printf '{"global":{"check_for_updates_on_startup":false},"profiles":[{"name":"Personal","selected":true,"devices":[{"custom":true}]}]}\n' >"$target"
cp "$target" "$tmp/original.json"
bash "$tmp/activate.sh"
jq -e '.global.check_for_updates_on_startup == false and (.profiles | length) == 2 and .profiles[0].selected == true and .profiles[1].name == "Personal" and .profiles[1].selected == false and .profiles[1].devices[0].custom == true' "$target" >/dev/null
backups=("$target".nixcfg-backup.*)
test "${#backups[@]}" = 1
cmp "$tmp/original.json" "${backups[0]}"

cp "$target" "$tmp/merged.json"
bash "$tmp/activate.sh"
cmp "$target" "$tmp/merged.json"
backups=("$target".nixcfg-backup.*)
test "${#backups[@]}" = 1

# Invalid user data must fail without replacing the file or making a backup.
printf '{"profiles":"broken"}\n' >"$target"
if bash "$tmp/activate.sh" >"$tmp/error.log" 2>&1; then
    echo "Expected invalid profiles to be rejected" >&2
    exit 1
fi
grep -q 'Expected a Karabiner configuration object' "$tmp/error.log"
test "$(cat "$target")" = '{"profiles":"broken"}'
backups=("$target".nixcfg-backup.*)
test "${#backups[@]}" = 1

printf '{broken\n' >"$target"
if bash "$tmp/activate.sh" >"$tmp/error.log" 2>&1; then
    echo "Expected malformed JSON to be rejected" >&2
    exit 1
fi
test "$(cat "$target")" = '{broken'

for invalid in '{"profiles":false}' '{"profiles":null}' '' '{}{}'; do
    printf '%s' "$invalid" >"$target"
    cp "$target" "$tmp/invalid.json"
    if bash "$tmp/activate.sh" >"$tmp/error.log" 2>&1; then
        echo "Expected invalid configuration to be rejected: $invalid" >&2
        exit 1
    fi
    cmp "$target" "$tmp/invalid.json"
done

rm "$target"
DRY_RUN_CMD=echo bash "$tmp/activate.sh"
test ! -e "$target"
bash "$tmp/activate.sh"
jq -e '(.profiles | length) == 1 and .profiles[0].selected == true' "$target" >/dev/null

# Replace a legacy file symlink without changing its original target.
rm "$target"
cp "$tmp/original.json" "$tmp/legacy.json"
ln -s "$tmp/legacy.json" "$target"
bash "$tmp/activate.sh"
test ! -L "$target"
cmp "$tmp/legacy.json" "$tmp/original.json"
jq -e '.profiles[0].selected == true' "$target" >/dev/null

node --input-type=module - "$root" <<'JS'
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const file = `${process.argv[2]}/dotfiles/vscode-1.106.2/.config/Code/User/keybindings.json`;
const bindings = JSON.parse(readFileSync(file, "utf8").replace(/^\/\/[^\n]*\n/, ""));
const terminal = bindings.filter(binding => binding.when === "isMac && terminalFocus");
assert.equal(terminal.length, 4);
assert.equal(terminal.find(binding => binding.key === "cmd+c").args.text, "\u0003");
assert.equal(terminal.find(binding => binding.key === "cmd+v").args.text, "\u0016");
assert.equal(terminal.find(binding => binding.key === "cmd+shift+c").command, "workbench.action.terminal.copySelection");
assert.equal(terminal.find(binding => binding.key === "cmd+shift+v").command, "workbench.action.terminal.paste");
JS
echo 'Loki keyboard configuration and profile migration checks passed.'
