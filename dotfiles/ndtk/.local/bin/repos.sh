#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
azure | github | local)
    provider="$1"
    shift
    exec "${HOME}/.local/bin/_repos_${provider}.py" "$@"
    ;;
"" | help | -h | --help)
    cat <<'EOF'
Usage: repos <source> <command> [options]

Manage repositories by source:
  azure     Azure DevOps repositories
  github    Personal and organization GitHub repositories
  local     Update repositories already present on disk

Run 'repos <source>' to list its commands.
Every source supports help, check and test.
EOF
    ;;
*)
    printf 'Unknown provider: %s. Choose azure, github or local.\n' "$1" >&2
    exit 2
    ;;
esac
