#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
script=$script_dir/../scripts/branch-compare.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

git_init() {
    local repo=$1
    git -C "$repo" init -q -b master
    git -C "$repo" config user.email test@example.invalid
    git -C "$repo" config user.name test
    git -C "$repo" config core.hooksPath /dev/null
}

assert_contains() {
    local haystack=$1
    local needle=$2
    case "$haystack" in
    *"$needle"*) ;;
    *)
        printf 'Expected output to contain: %s\n' "$needle" >&2
        exit 1
        ;;
    esac
}

repo=$test_root/repo
mkdir "$repo"
git_init "$repo"
printf 'base\n' >"$repo/value.txt"
printf 'base lock\n' >"$repo/flake.lock"
git -C "$repo" add value.txt flake.lock
git -C "$repo" commit -q -m 'fixture: create base commit'
git -C "$repo" branch dev
git -C "$repo" branch develop
git -C "$repo" branch development
git -C "$repo" checkout -q -b feature
printf 'feature\n' >"$repo/value.txt"
git -C "$repo" commit -qam 'fixture: change feature commit'

report=$(bash "$script" --repo "$repo")
assert_contains "$report" 'Base branch: dev'
assert_contains "$report" 'Current branch: feature'
assert_contains "$report" '## Commits'
assert_contains "$report" '## Changed paths'
assert_contains "$report" '## Patch'
assert_contains "$report" 'fixture: change feature commit'

git -C "$repo" branch -D dev >/dev/null
report=$(bash "$script" --repo "$repo")
assert_contains "$report" 'Base branch: develop'

git -C "$repo" branch -D develop >/dev/null
report=$(bash "$script" --repo "$repo")
assert_contains "$report" 'Base branch: development'

git -C "$repo" branch dev master
printf 'working-tree\n' >"$repo/value.txt"
report=$(bash "$script" --repo "$repo" --base dev)
assert_contains "$report" 'Worktree: dirty'
assert_contains "$report" 'value.txt'

if bash "$script" --repo "$repo" --base feature >/dev/null 2>&1; then
    printf 'Expected same-branch comparison to fail.\n' >&2
    exit 1
fi

printf 'changed lock\n' >"$repo/flake.lock"
printf 'new content  \n' >"$repo/new.txt"
report=$(bash "$script" --repo "$repo" --base dev)
assert_contains "$report" $'tracked\tM\tflake.lock'
assert_contains "$report" $'untracked\t-\tnew.txt'
assert_contains "$report" $'1\t0\tnew.txt'
assert_contains "$report" 'new.txt:1: trailing whitespace.'
patch_dir=$(sed -n 's/^- Patch output directory: //p' <<<"$report")
assert_contains "$(cat "$patch_dir/flake.lock.patch")" 'changed lock'
assert_contains "$(cat "$patch_dir/new.txt.patch")" 'new content'
rm -- "$repo/new.txt"
report=$(bash "$script" --repo "$repo" --base dev)
assert_contains "$report" $'tracked\tM\tflake.lock'

git -C "$repo" checkout -q -- value.txt
git -C "$repo" checkout -q -- flake.lock
git -C "$repo" checkout -q master
if bash "$script" --repo "$repo" >/dev/null 2>&1; then
    printf 'Expected empty base comparison to fail.\n' >&2
    exit 1
fi

git -C "$repo" checkout -qb untracked-only
printf 'only untracked\n' >"$repo/new.txt"
report=$(bash "$script" --repo "$repo" --base dev)
assert_contains "$report" $'untracked\t-\tnew.txt'
patch_dir=$(sed -n 's/^- Patch output directory: //p' <<<"$report")
assert_contains "$(cat "$patch_dir/new.txt.patch")" 'only untracked'

printf 'branch-compare tests passed\n'
