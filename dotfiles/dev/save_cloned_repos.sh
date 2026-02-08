#!/usr/bin/env bash

set -euo pipefail

SEARCH_DIR="${1:-$HOME/dev}"
REPOS_FILE="${2:-$SEARCH_DIR/repos}"

if [[ ! -d "$SEARCH_DIR" ]]; then
	echo "Directory not found: $SEARCH_DIR"
	exit 1
fi

mkdir -p "$(dirname "$REPOS_FILE")"
touch "$REPOS_FILE"

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

echo "Scanning git repositories in $SEARCH_DIR..."

while IFS= read -r gitdir; do
	repo_path=$(dirname "$gitdir")
	origin_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || true)

	if [[ -n "$origin_url" ]] && [[ "$origin_url" =~ ^(https?|ssh|git|file)://|^[^@[:space:]]+@[^:[:space:]]+: ]]; then
		printf '%s\n' "$origin_url" >>"$tmp_file"
	fi
done < <(find "$SEARCH_DIR" \( -type d -name ".git" -o -type f -name ".git" \) -print)

LC_ALL=C sort -f -u "$tmp_file" >"$REPOS_FILE"

echo "Saved $(wc -l <"$REPOS_FILE") repository URL(s) to $REPOS_FILE"
