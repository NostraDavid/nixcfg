#!/usr/bin/env bash
set -euo pipefail

message=${2:-}
if [[ $# -ne 2 || ! $message =~ [^[:space:]] ]]; then
    printf 'Usage: %s question|done "short message"\n' "$0" >&2
    exit 2
fi

case "$1" in
question | done) ;;
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

repository=''
if git_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    repository=$(dirname -- "$git_dir")
    if [[ ${repository##*/} == trunk ]]; then
        repository=$(dirname -- "$repository")
    fi
    repository=${repository##*/}
fi

exec timeout -k 1 10 say "biep boep. ${repository:+$repository. }$message"
