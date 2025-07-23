#!/usr/bin/env bash

set -euo pipefail

# Check for gh
if ! command -v gh &>/dev/null; then
	echo "gh could not be found. Please install the GitHub CLI."
	exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
	echo "jq could not be found. Please install jq."
	exit 1
fi

TARGET_DIR="${1:-$HOME/dev}"
mkdir -p "$TARGET_DIR"

echo "Cloning/pulling repos into $TARGET_DIR"

clone_or_pull() {
	local repo_url=$1
	local org_and_repo
	org_and_repo=$(echo "$repo_url" | sed -e 's|git@github.com:||' -e 's|.git$||')
	local target_path="$TARGET_DIR/$org_and_repo"
	local target_repo_dir
	target_repo_dir=$(dirname "$target_path")

	mkdir -p "$target_repo_dir"

	if [ -d "$target_path" ]; then
		echo "Pulling $org_and_repo..."
		(cd "$target_path" && git pull)
	else
		echo "Cloning $org_and_repo..."
		git clone "$repo_url" "$target_path"
	fi
}

# Get user
USER=$(gh api user --jq '.login')

# Personal repos
echo "--- Processing personal repos for $USER ---"
gh repo list "$USER" --limit 1000 --json sshUrl | jq -r '.[].sshUrl' | while read -r repo_url; do
	clone_or_pull "$repo_url"
done

# Organization repos
echo "--- Processing organization repos ---"
gh api user/orgs --jq '.[].login' | while read -r org; do
	echo "--- Processing repos for organization $org ---"
	gh repo list "$org" --limit 1000 --json sshUrl | jq -r '.[].sshUrl' | while read -r repo_url; do
		clone_or_pull "$repo_url"
	done
done

echo "--- All repositories processed. ---"
