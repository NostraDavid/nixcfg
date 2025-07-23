#!/usr/bin/env bash

set -euo pipefail

SEARCH_DIR="${1:-$HOME/dev}"

if [ ! -d "$SEARCH_DIR" ]; then
	echo "Directory not found: $SEARCH_DIR"
	exit 1
fi

echo "Searching for repositories with uncommitted or unpushed changes in $SEARCH_DIR..."

find "$SEARCH_DIR" -type d -name ".git" | while read -r gitdir; do
	repo_path="$(dirname "$gitdir")"

	(
		cd "$repo_path" || continue

		# Check for uncommitted changes (staged or unstaged)
		if ! git diff --quiet --ignore-submodules HEAD; then
			echo "----------------------------------------"
			echo "Repo: $repo_path"
			echo "  - Has uncommitted changes."
			git status -s
			continue # Skip to next repo if changes found
		fi

		# Check for unpushed commits
		if [ -n "$(git log @{u}..)" ]; then
			echo "----------------------------------------"
			echo "Repo: $repo_path"
			echo "  - Has unpushed commits."
			git status -sb
		fi
	)
done

echo "Search complete."
