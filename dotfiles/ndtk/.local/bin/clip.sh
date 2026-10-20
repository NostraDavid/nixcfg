#!/bin/sh
set -eu

if [ "$#" -ne 0 ]; then
    echo 'Usage: program | clip' >&2
    exit 2
fi

if [ "$(uname -s)" = Darwin ]; then
    exec pbcopy
elif [ -n "${WAYLAND_DISPLAY:-}" ] && command -v wl-copy >/dev/null 2>&1; then
    exec wl-copy
elif [ -n "${DISPLAY:-}" ] && command -v xclip >/dev/null 2>&1; then
    exec xclip -selection clipboard
else
    echo 'clip: no clipboard available; Linux needs wl-copy with Wayland or xclip with X11.' >&2
    exit 1
fi
