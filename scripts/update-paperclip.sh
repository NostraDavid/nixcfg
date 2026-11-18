#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
pkg_dir="$repo_root/pkgs/paperclip"
tmp="$(mktemp -d)"
cp "$pkg_dir/default.nix" "$tmp/default.nix"
cp "$pkg_dir/package-lock.json" "$tmp/package-lock.json"
restore() {
    cp "$tmp/default.nix" "$pkg_dir/default.nix"
    cp "$tmp/package-lock.json" "$pkg_dir/package-lock.json"
}
trap restore ERR
trap 'rm -rf "$tmp"' EXIT

nix run nixpkgs#nix-update -- -F paperclip --src-only
if [[ ${NIXCFG_SKIP_UNCHANGED:-0} == 1 ]] && cmp -s "$tmp/default.nix" "$pkg_dir/default.nix"; then
    echo 'Paperclip source unchanged.'
    exit 0
fi
src="$(nix build .#paperclip.src --no-link --print-out-paths)"
node="$(nix build .#paperclip.nodejs --no-link --print-out-paths)"
overrides="$(nix eval --json .#paperclip.npmOverrides)"
mkdir "$tmp/source"
# nix-update generates locks before postPatch, so apply the package's overrides here.
tar -xOf "$src" package/package.json |
    jq --argjson overrides "$overrides" '.overrides = $overrides' >"$tmp/source/package.json"
cp "$pkg_dir/package-lock.json" "$tmp/source/package-lock.json"
"$node/bin/npm" install --package-lock-only --ignore-scripts --no-audit --no-fund \
    --prefix "$tmp/source" --cache "$tmp/npm-cache"
# shortcut: repairs npm's bundled Claude SDK omissions; remove when npm/cli#9821 is fixed.
jq '
    . as $lock
    | "node_modules/@paperclipai/server/node_modules/@agentclientprotocol/claude-agent-acp" as $adapter
    | "node_modules/@anthropic-ai/claude-agent-sdk" as $sdk
    | if $lock.packages[$sdk].version != null
         and $lock.packages[$adapter].inBundle == true
         and $lock.packages[$adapter + "/" + $sdk] == null
         and $lock.packages[$adapter].dependencies["@anthropic-ai/claude-agent-sdk"] == $lock.packages[$sdk].version
         and $lock.packages["node_modules/@paperclipai/server/" + $sdk].version != $lock.packages[$sdk].version
      then reduce ([$sdk] + (($lock.packages[$sdk].optionalDependencies // {}) | keys | map("node_modules/" + .)))[] as $entry
        (.; .packages[$adapter + "/" + $entry] = ($lock.packages[$entry] // error("Missing Claude SDK lock entry: " + $entry)))
      else . end
' "$tmp/source/package-lock.json" >"$pkg_dir/package-lock.json"
nix run nixpkgs#nix-update -- -F paperclip --version=skip
nix build .#paperclip --no-link

trap - ERR
echo 'paperclip update complete.'
