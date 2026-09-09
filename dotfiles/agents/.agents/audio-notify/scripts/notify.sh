#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage: %s question|done\n' "$0" >&2
    exit 2
fi

case "$1" in
question) message='Ik heb een vraag.' ;;
done) message='De taak is klaar.' ;;
*)
    printf 'Unknown notification event: %s\n' "$1" >&2
    exit 2
    ;;
esac

[[ ${AGENT_NOTIFY_MUTE:-0} == 1 ]] && exit 0

if ! command -v say >/dev/null 2>&1; then
    printf 'Audio notifications need say on PATH.\n' >&2
    exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
    printf 'Audio notifications need timeout on PATH.\n' >&2
    exit 1
fi

exec timeout -k 1 5 say "biep boep. $message"
