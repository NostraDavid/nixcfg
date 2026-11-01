#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
notify="$root/dotfiles/agents/.agents/audio-notify/scripts/notify.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
stubs=$tmp/bin
events=$tmp/events
mkdir -p "$stubs" "$events"

cat >"$stubs/timeout" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == -k && ${2:-} == 1 && ${3:-} == 30 ]]
shift 3
exec "$@"
SH

cat >"$stubs/say" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == piper && $# == 2 ]]
label=${2##* }
event_dir=${AUDIO_NOTIFY_TEST_EVENTS:?}
if ! mkdir "$event_dir/active" 2>/dev/null; then
    printf 'overlap %s\n' "$label" >>"$event_dir/events"
    exit 1
fi
trap 'rmdir "$event_dir/active"' EXIT
printf 'start %s\n' "$label" >>"$event_dir/events"
sleep 0.2
printf 'end %s\n' "$label" >>"$event_dir/events"
SH
chmod +x "$stubs/timeout" "$stubs/say"

export XDG_STATE_HOME=$tmp/state
export AUDIO_NOTIFY_TEST_EVENTS=$events
export PATH=$stubs:$PATH
cd "$tmp"

"$notify" 'done' alpha &
first=$!
"$notify" 'done' bravo &
second=$!
wait "$first"
wait "$second"

[[ -f $XDG_STATE_HOME/audio-notify/playback.lock ]]
awk '
    NR % 2 == 1 { if ($1 != "start") failed = 1; current = $2 }
    NR % 2 == 0 { if ($1 != "end" || $2 != current) failed = 1 }
    END { if (NR != 4 || failed) exit 1 }
' "$events/events"

AGENT_NOTIFY_MUTE=1 "$notify" 'done' muted
[[ $(wc -l <"$events/events" | tr -d '[:space:]') == 4 ]]
[[ $(wc -l <"$XDG_STATE_HOME/audio-notify/notifications.log" | tr -d '[:space:]') == 3 ]]

printf 'Audio notifications queue playback and preserve mute behavior.\n'
