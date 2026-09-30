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

repository=''
if git_dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    repository=$(dirname -- "$git_dir")
    if [[ ${repository##*/} == trunk ]]; then
        repository=$(dirname -- "$repository")
    fi
    repository=${repository##*/}
fi

state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
log_dir=$state_home/audio-notify
log_file=$log_dir/notifications.log
(
    umask 077
    mkdir -p -- "$log_dir"
    chmod 700 -- "$log_dir"
    : >>"$log_file"
    chmod 600 -- "$log_file"
    printf '%s\t%s\t%s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$repository" "$message" >>"$log_file"
)

[[ ${AGENT_NOTIFY_MUTE:-0} == 1 ]] && exit 0

if ! command -v say >/dev/null 2>&1; then
    printf 'Audio notifications need say on PATH.\n' >&2
    exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
    printf 'Audio notifications need timeout on PATH.\n' >&2
    exit 1
fi

exec timeout -k 1 30 say piper "biep boep. ${repository:+$repository. }$message"
