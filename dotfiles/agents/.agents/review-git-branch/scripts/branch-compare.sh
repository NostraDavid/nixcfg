#!/usr/bin/env bash

set -euo pipefail

usage() {
    cat <<'EOF'
Usage: branch-compare.sh [--repo PATH] [--base REF]

Print a read-only Markdown branch-comparison report. Without --base, the
first usable ref from dev, develop, development, master, main and their origin
counterparts is used.
EOF
}

repo_path=.
requested_base=
diff_pathspec=(.)
skip_patch_regex='\.(svg|drawio\.svg|png|jpe?g|gif|webp|bmp|ico|min\.(js|css)|pdf)$'
always_skip_patch_regex='\.(parquet|parq)$'
large_data_patch_regex='\.(csv|json|ndjson|jsonl|tsv)$'
large_data_patch_bytes=${BRANCH_COMPARE_LARGE_DATA_PATCH_BYTES:-50000}
patch_output_dir=${BRANCH_COMPARE_PATCH_DIR:-}

while (($# > 0)); do
    case "$1" in
    --base | -b)
        if (($# < 2)); then
            printf 'Fout: --base verwacht een Git-ref.\n' >&2
            exit 2
        fi
        requested_base=$2
        shift 2
        ;;
    --repo)
        if (($# < 2)); then
            printf 'Fout: --repo verwacht een pad.\n' >&2
            exit 2
        fi
        repo_path=$2
        shift 2
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    *)
        printf 'Fout: onbekende optie: %s\n' "$1" >&2
        usage >&2
        exit 2
        ;;
    esac
done

cd -- "$repo_path"

current_ref=$(git symbolic-ref --quiet --short HEAD) || {
    printf 'Fout: HEAD staat niet op een branch.\n' >&2
    exit 1
}

current_commit=$(git rev-parse --verify HEAD)
repo_root=$(git rev-parse --show-toplevel)
untracked_paths=$(git ls-files --others --exclude-standard -- "${diff_pathspec[@]}")

base_ref=
merge_base=

usable_base() {
    local candidate=$1
    local candidate_commit
    local candidate_merge_base

    [ "$candidate" != "$current_ref" ] || return 1
    candidate_commit=$(git rev-parse --verify --quiet "$candidate^{commit}") || return 1
    [ -n "$candidate_commit" ] || return 1
    candidate_merge_base=$(git merge-base HEAD "$candidate") || return 1

    # Do not silently review an empty comparison. Uncommitted tracked changes
    # are included, so a branch with a dirty worktree remains reviewable.
    if git diff --quiet "$candidate_merge_base" -- "${diff_pathspec[@]}" && [ -z "$untracked_paths" ]; then
        return 1
    fi

    base_ref=$candidate
    merge_base=$candidate_merge_base
    return 0
}

if [ -n "$requested_base" ]; then
    if ! usable_base "$requested_base"; then
        printf 'Fout: basisref %s bestaat niet, is de huidige branch, of levert geen diff op.\n' \
            "$requested_base" >&2
        exit 1
    fi
else
    for candidate in \
        dev develop development \
        origin/dev origin/develop origin/development \
        master main \
        origin/master origin/main; do
        if usable_base "$candidate"; then
            break
        fi
    done

    if [ -z "$base_ref" ]; then
        printf 'Fout: geen niet-lege basisbranch gevonden; geef --base REF op.\n' >&2
        exit 1
    fi
fi

commit_count=$(git rev-list --count "$merge_base..HEAD")
status=$(git status --short --untracked-files=all -- "${diff_pathspec[@]}")
changed_paths=$(git diff --name-status --find-renames --find-copies "$merge_base" -- "${diff_pathspec[@]}")
diff_numstat=$(git diff --numstat --find-renames --find-copies "$merge_base" -- "${diff_pathspec[@]}")
diff_check=$(git diff --check "$merge_base" -- "${diff_pathspec[@]}" 2>&1 || true)
changed_files=$(git diff --name-only --find-renames --find-copies "$merge_base" -- "${diff_pathspec[@]}")
if [ -n "$untracked_paths" ]; then
    changed_files+=$'\n'"$untracked_paths"
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        numstat=$(git diff --no-index --numstat -- /dev/null "$path" || [ "$?" -eq 1 ])
        IFS=$'\t' read -r added removed _ <<<"$numstat"
        diff_numstat+=$'\n'"$added"$'\t'"$removed"$'\t'"$path"
        check=$(git diff --no-index --check -- /dev/null "$path" 2>&1 || true)
        if [ -n "$check" ]; then
            [ -z "$diff_check" ] || diff_check+=$'\n'
            diff_check+="$check"
        fi
    done <<<"$untracked_paths"
fi

if [ -z "$patch_output_dir" ]; then
    patch_output_dir=$(mktemp -d "${TMPDIR:-/tmp}/branch-compare.XXXXXX")
else
    mkdir -p -- "$patch_output_dir"
fi

patch_output_dir=$(cd -- "$patch_output_dir" && pwd)

file_max_size_bytes() {
    local path=$1
    local old_size=0
    local new_size=0

    if git cat-file -e "$merge_base:$path" 2>/dev/null; then
        old_size=$(git cat-file -s "$merge_base:$path")
    fi
    if [ -e "$path" ]; then
        new_size=$(wc -c <"$path")
    fi

    if [ "$old_size" -ge "$new_size" ]; then
        printf '%s\n' "$old_size"
    else
        printf '%s\n' "$new_size"
    fi
}

should_skip_patch_for_file() {
    local path=$1
    local max_size

    if printf '%s\n' "$path" | grep -Eq "$skip_patch_regex"; then
        return 0
    fi

    if printf '%s\n' "$path" | grep -Eq "$always_skip_patch_regex"; then
        return 0
    fi

    if printf '%s\n' "$path" | grep -Eq "$large_data_patch_regex"; then
        max_size=$(file_max_size_bytes "$path")
        if [ "$max_size" -gt "$large_data_patch_bytes" ]; then
            return 0
        fi
    fi

    return 1
}

write_patch_file() {
    local path=$1
    local patch_file="$patch_output_dir/$path.patch"

    mkdir -p -- "$(dirname -- "$patch_file")"
    if git ls-files --error-unmatch -- ":(literal)$path" >/dev/null 2>&1; then
        git --no-pager diff \
            --no-ext-diff \
            --no-textconv \
            --no-color \
            --find-renames \
            --find-copies \
            "$merge_base" \
            -- "$path" >"$patch_file"
    else
        git --no-pager diff --no-index --no-ext-diff --no-textconv --no-color \
            -- /dev/null "$path" >"$patch_file" || [ "$?" -eq 1 ]
    fi

    printf '%s\n' "$patch_file"
}

printf '%s\n\n' '# Branch comparison'
printf '%s\n' "- Repository: $repo_root"
printf '%s\n' "- Current branch: $current_ref ($current_commit)"
printf '%s\n' "- Base branch: $base_ref"
printf '%s\n' "- Merge base: $merge_base"
printf '%s\n' "- Branch commits since merge base: $commit_count"
printf '%s\n' "- Worktree: $([ -n "$status" ] && printf 'dirty' || printf 'clean')"
printf '%s\n' "- Patch output directory: $patch_output_dir"
printf '\n'

printf '%s\n\n' '## Commits'
if [ "$commit_count" -eq 0 ]; then
    printf '%s\n\n' 'No commits exist after the merge base; only working-tree changes are present.'
else
    git --no-pager log --no-decorate --format='- %h %s' "$merge_base..HEAD"
    printf '\n'
fi

printf '%s\n\n' '## Diff stat'
printf '%s\n' '```tsv'
printf '%s\n' $'total_changes\tadded_lines\tremoved_lines\tpath'
if [ -n "$diff_numstat" ]; then
    while IFS=$'\t' read -r added removed path; do
        [ -n "$path" ] || continue
        case $added in
        '' | -) added='bin' ;;
        esac
        case $removed in
        '' | -) removed='bin' ;;
        esac

        if [[ "$added" == 'bin' || "$removed" == 'bin' ]]; then
            total='bin'
        else
            total=$((added + removed))
        fi

        printf '%s\t%s\t%s\t%s\n' "$total" "$added" "$removed" "$path"
    done <<EOF
$diff_numstat
EOF
else
    printf '%s\t%s\t%s\t%s\n' '-' '-' '-' 'no_tracked_file_changes'
fi
printf '%s\n\n' '```'

printf '%s\n\n' '## Changed paths'
printf '%s\n' '```tsv'
printf '%s\n' $'entry_kind\tchange_status\tpath'
if [ -n "$changed_paths" ]; then
    while IFS=$'\t' read -r status path; do
        [ -n "$status" ] || continue
        printf '%s\t%s\t%s\n' 'tracked' "$status" "$path"
    done <<EOF
$changed_paths
EOF
else
    printf '%s\t%s\t%s\n' '-' '-' 'no_tracked_file_changes'
fi
if [ -n "$untracked_paths" ]; then
    while IFS= read -r path; do
        [ -n "$path" ] || continue
        printf '%s\t%s\t%s\n' 'untracked' '-' "$path"
    done <<EOF
$untracked_paths
EOF
fi
printf '%s\n\n' '```'

printf '%s\n\n' '## Diff checks'
if [ -n "$diff_check" ]; then
    printf '%s\n' 'Whitespace errors:'
    printf '%s\n' '```text' "$diff_check" '```'
else
    printf '%s\n\n' 'No whitespace errors reported by git diff --check.'
fi

printf '%s\n\n' '## Patch omissions'
printf '%s\n' '```yaml'
omitted_any=0
while IFS= read -r path; do
    [ -n "$path" ] || continue
    if should_skip_patch_for_file "$path"; then
        omitted_any=1
        printf '%s\n' "- path: $path"
        if printf '%s\n' "$path" | grep -Eq "$skip_patch_regex"; then
            printf '%s\n' '  reason: image/generated asset matched skip regex'
            printf '%s\n' "  rule: $skip_patch_regex"
            printf '%s\n' '  size: null'
            printf '%s\n' '  threshold: null'
        elif printf '%s\n' "$path" | grep -Eq "$always_skip_patch_regex"; then
            printf '%s\n' '  reason: binary data file matched always-skip regex'
            printf '%s\n' "  rule: $always_skip_patch_regex"
            printf '%s\n' '  size: null'
            printf '%s\n' '  threshold: null'
        else
            printf '%s\n' '  reason: large line-based data file matched size rule'
            printf '%s\n' "  rule: $large_data_patch_regex"
            printf '%s\n' "  size: $(file_max_size_bytes "$path")"
            printf '%s\n' "  threshold: $large_data_patch_bytes"
        fi
        printf '%s\n' "  patch_file: $(write_patch_file "$path")"
        printf '%s\n' '  note: do_not_read_fully_unless_needed'
    fi
done <<EOF
$changed_files
EOF
if [ "$omitted_any" -eq 0 ]; then
    printf '%s\n' '[]'
fi
printf '%s\n\n' '```'

printf '%s\n\n' '## Patch files'
printf '%s\n' '```tsv'
printf '%s\n' $'path\tpatch_file'
patch_files_any=0
while IFS= read -r path; do
    [ -n "$path" ] || continue
    if should_skip_patch_for_file "$path"; then
        continue
    fi

    patch_files_any=1
    printf '%s\t%s\n' "$path" "$(write_patch_file "$path")"
done <<EOF
$changed_files
EOF
if [ "$patch_files_any" -eq 0 ]; then
    printf '%s\t%s\n' '-' 'no_inline_patch_files_generated'
fi
printf '%s\n' '```'
