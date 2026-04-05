#!/usr/bin/env bash
# Archive URLs with the Internet Archive Save Page Now API.
#
# One-time setup:
#   uv tool install savepagenow
#
# Usage:
#   cmd/archive-urls.sh urls.txt

set -euo pipefail

urls_file="${1:-urls.txt}"

if [[ ! -f "${urls_file}" ]]; then
  printf 'URL list not found: %s\n' "${urls_file}" >&2
  exit 1
fi

if ! command -v savepagenow >/dev/null 2>&1; then
  printf 'savepagenow is not installed. Run: uv tool install savepagenow\n' >&2
  exit 1
fi

while IFS= read -r url; do
  [[ -z "${url}" ]] && continue

  printf 'Archiving: %s\n' "${url}"

  savepagenow "${url}" \
    --user-agent "DavidArchiveBot/0.1"

  sleep "$((65 + RANDOM % 20))"
done <"${urls_file}"
