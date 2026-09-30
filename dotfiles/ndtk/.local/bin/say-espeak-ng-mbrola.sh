#!/usr/bin/env bash
set -euo pipefail

# Agent tools may omit the desktop session's runtime directory.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

# Keep the compiled pronunciation dictionary used by `say`.
data_path="${SAY_DATA_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/say}"

# eSpeak NG finds MBROLA voices below XDG data directories. Home Manager
# installs nl2 at this location; SAY_ESPEAK_NG_MBROLA_DATA_PATH can point to
# another root.
voice_data="${SAY_ESPEAK_NG_MBROLA_DATA_PATH:-${XDG_DATA_HOME:-$HOME/.local/share}}"
if [[ ! -r "$voice_data/mbrola/nl2/nl2" ]]; then
    printf 'say-espeak-ng-mbrola: MBROLA-stem nl2 ontbreekt: %s\n' "$voice_data/mbrola/nl2/nl2" >&2
    exit 1
fi

if [[ -n "${XDG_DATA_DIRS:-}" ]]; then
    export XDG_DATA_DIRS="$voice_data:$XDG_DATA_DIRS"
else
    export XDG_DATA_DIRS="$voice_data"
fi

# -v mb-nl2: Dutch MBROLA voice nl2.
# -s 200: speed in words per minute.
# -p 0: lowest pitch; -P 0: monotone pitch range.
# -a 200: maximum amplitude, matching `say`.
exec espeak-ng --path="$data_path" -v mb-nl2 -s 200 -p 0 -P 0 -a 200 "$@"
