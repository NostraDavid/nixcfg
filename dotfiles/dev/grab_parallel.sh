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

# Determine concurrency (override with JOBS env). Cap at 8 by default.
detect_cpus() {
	if command -v nproc >/dev/null 2>&1; then
		nproc
	elif command -v sysctl >/dev/null 2>&1; then
		sysctl -n hw.ncpu 2>/dev/null || echo 4
	else
		echo 4
	fi
}

if [[ -n "${JOBS:-}" ]]; then
	JOBS=${JOBS}
else
	CPUS=$(detect_cpus)
	if [[ "$CPUS" -gt 8 ]]; then
		JOBS=8
	else
		JOBS=$CPUS
	fi
fi

echo "Cloning/pulling repos into $TARGET_DIR using $JOBS parallel jobs"

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

# Collect all repos first
USER=$(gh api user --jq '.login')

echo "--- Gathering personal repos for $USER ---"
mapfile -t PERSONAL_REPOS < <(gh repo list "$USER" --limit 1000 --json sshUrl | jq -r '.[].sshUrl')

echo "--- Gathering organization repos ---"
mapfile -t ORGS < <(gh api user/orgs --jq '.[].login')
ORG_REPOS=()
for org in "${ORGS[@]}"; do
	echo "   - $org"
	mapfile -t repo_urls < <(gh repo list "$org" --limit 1000 --json sshUrl | jq -r '.[].sshUrl')
	ORG_REPOS+=("${repo_urls[@]}")
done

ALL_REPOS=("${PERSONAL_REPOS[@]}" "${ORG_REPOS[@]}")

if [[ ${#ALL_REPOS[@]} -eq 0 ]]; then
	echo "No repositories found."
	exit 0
fi

echo "--- Processing ${#ALL_REPOS[@]} repositories in parallel ---"

# Run with bounded parallelism
error_file=$(mktemp)
running=0

for repo_url in "${ALL_REPOS[@]}"; do
	(
		if ! clone_or_pull "$repo_url"; then
			echo "$repo_url" >>"$error_file"
		fi
	) &
	((running += 1))
	if ((running >= JOBS)); then
		# wait for any job to finish; ignore exit code (handled above)
		wait -n || true
		((running -= 1))
	fi
done

# Wait for remaining jobs
while ((running > 0)); do
	wait -n || true
	((running -= 1))
done

if [[ -s "$error_file" ]]; then
	echo "--- Some repositories failed ---"
	sort -u "$error_file" | sed 's/^/  - /'
	rm -f "$error_file"
	exit 1
fi

rm -f "$error_file"
echo "--- All repositories processed successfully. ---"
