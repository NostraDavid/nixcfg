#!/usr/bin/env bash
set -euo pipefail

# Agent tools may omit the desktop session's runtime directory.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

model="${PIPER_MODEL:-${XDG_DATA_HOME:-$HOME/.local/share}/piper-voices/nl_NL-pim-medium.onnx}"
config="${PIPER_CONFIG:-$model.json}"
if [[ ! -r "$model" ]]; then
    cat >&2 <<EOF
say-piper-tts: Piper-model ontbreekt: $model
Plaats nl_NL-pim-medium.onnx en het bijbehorende .onnx.json-bestand daar,
of stel PIPER_MODEL in op een ander Piper-modelbestand.
EOF
    exit 1
fi
if [[ ! -r "$config" ]]; then
    printf 'say-piper-tts: Piper-configuratie ontbreekt: %s\n' "$config" >&2
    exit 1
fi

output_file=$(mktemp --suffix=.wav "${TMPDIR:-/tmp}/say-piper-tts.XXXXXX")
trap 'rm -f "$output_file"' EXIT

# The Dutch Piper voice otherwise applies Dutch phonemization to these terms.
# Raw phoneme blocks keep their English pronunciation while retaining the
# selected Dutch voice for the rest of the text.
english_terms() {
    sed \
        -e 's/\<scoped\>/[[skˈoʊpd]]/g' \
        -e 's/\<message\>/[[mˈɛsɪdʒ]]/g'
}

if (($# > 0)); then
    printf '%s\n' "$*" | english_terms | piper --model "$model" --config "$config" --output-file "$output_file"
else
    english_terms | piper --model "$model" --config "$config" --output-file "$output_file"
fi

player="${SAY_PIPER_TTS_PLAYER:-pw-play}"
"$player" "$output_file"
