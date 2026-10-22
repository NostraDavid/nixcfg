#!/usr/bin/env bash
set -euo pipefail

bin_dir="${HOME}/.local/bin"

usage() {
    cat <<'EOF'
Usage: repos <source> <command> [options]

Run 'repos <source> --help' for source options.
Available sources are executable _repos_<source>.py plugins in ~/.local/bin:
EOF

    local plugin plugin_name found=false
    for plugin in "${bin_dir}"/_repos_*.py; do
        [[ -x "$plugin" ]] || continue
        plugin_name="${plugin##*/_repos_}"
        plugin_name="${plugin_name%.py}"
        [[ "$plugin_name" =~ ^[a-z][a-z0-9_-]*$ ]] || continue
        printf '  %s\n' "$plugin_name"
        found=true
    done
    if [[ "$found" == false ]]; then
        printf '  (none)\n'
    fi
}

provider="${1:-}"
case "$provider" in
"" | -h | --help)
    usage
    exit 0
    ;;
esac

if [[ ! "$provider" =~ ^[a-z][a-z0-9_-]*$ ]]; then
    printf 'Invalid provider name: %s\n' "$provider" >&2
    exit 2
fi

shift
plugin="${bin_dir}/_repos_${provider}.py"
if [[ ! -x "$plugin" ]]; then
    printf 'Unknown provider: %s\n' "$provider" >&2
    usage >&2
    exit 2
fi

exec "$plugin" "$@"
