#!/usr/bin/env bash
set -euo pipefail

rules="$(dirname "$(readlink -f -- "$0")")/piper.sed"
input='nixcfg scoped message. unscoped nixcfgx messages xmessage.'
expected=$'niks config [[sk\u02c8oʊpd]] [[m\u02c8ɛsɪdʒ]]. unscoped nixcfgx messages xmessage.'
actual=$(printf '%s\n' "$input" | sed -f "$rules")
[[ "$actual" == "$expected" ]]
printf 'Piper-uitspraakregels en woordgrenzen: OK\n'

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/config/say"
cp "$rules" "$tmp/config/say/piper.sed"
touch "$tmp/model.onnx" "$tmp/model.onnx.json"
cat >"$tmp/bin/piper" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
EOF
cat >"$tmp/bin/afplay" <<'EOF'
#!/usr/bin/env bash
[[ -f $1 ]] || exit 1
printf '%s\n' "${0##*/}" >> "$PIPER_TEST_PLAYERS"
EOF
cp "$tmp/bin/afplay" "$tmp/bin/override-player"
chmod +x "$tmp/bin/"*
export PATH="$tmp/bin:$PATH" XDG_CONFIG_HOME="$tmp/config" PIPER_MODEL="$tmp/model.onnx"
export PIPER_TEST_PLAYERS="$tmp/players"
backend="$(dirname "$rules")/../ndtk/.local/bin/say-piper-tts.sh"
SAY_PIPER_TTS_PLAYER='' bash "$backend" 'Test macOS audio'
SAY_PIPER_TTS_PLAYER="$tmp/bin/override-player" bash "$backend" 'Test override'
[[ $(cat "$PIPER_TEST_PLAYERS") == $'afplay\noverride-player' ]]
printf 'Piper afplay en speler-override: OK\n'
