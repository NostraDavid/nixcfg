#!/usr/bin/env bash

# Agent tools may omit the desktop session's runtime directory.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"

# This directory contains espeak-ng-data with the compiled pronunciation list.
data_path="${SAY_DATA_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/say}"

# eSpeak NG options below have no long equivalents:
# -v nl: Dutch voice (list voices: espeak-ng --voices).
# -s 200: speed in words per minute (default: 175).
# -p 0: pitch, 0-99 (default: 50; 0 is lowest).
# -P 0: pitch range, 0-99 (default: 50; 0 is monotone).
# -a 200: amplitude, 0-200 (default: 100; 200 is maximum).
# Usage: say "Build complete"; override options: say -v nl -s 150 "Klaar".
exec espeak-ng --path="$data_path" -v nl -s 200 -p 0 -P 0 -a 200 "$@"
