#!/usr/bin/env bash
set -euo pipefail

script_path="$(readlink -f -- "$0")"
script_dir="$(cd -- "$(dirname -- "$script_path")" && pwd)"

usage() {
    cat <<'EOF'
Gebruik: say [stem] [tekst ...]

Stemmen:
  espeak-ng              eSpeak NG Nederlands (standaard)
  espeak-ng-mbrola       eSpeak NG met MBROLA nl2
  piper                  Piper nl_NL-pim-medium

Zonder tekst leest de gekozen stem van stdin.
EOF
}

if [[ ${1-} == "-h" || ${1-} == "--help" ]]; then
    usage
    exit 0
fi

engine="espeak-ng"
case ${1-} in
espeak-ng | espeak)
    engine="espeak-ng"
    shift
    ;;
espeak-ng-mbrola | mbrola)
    engine="espeak-ng-mbrola"
    shift
    ;;
piper | piper-tts)
    engine="piper-tts"
    shift
    ;;
esac

exec "$script_dir/say-$engine.sh" "$@"
