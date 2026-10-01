#!/usr/bin/env bash

folder_count() {
    local dir count file git_worktree=0

    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git_worktree=1
    fi

    for dir in */; do
        [[ -d "$dir" ]] || continue
        count=0

        if ((git_worktree)); then
            while IFS= read -r -d '' file; do
                if [[ -f "$file" && ! -L "$file" && "/$file" != */__pycache__/* ]]; then
                    count=$((count + 1))
                fi
            done < <(git ls-files -z --cached --others --exclude-standard -- "$dir")
        else
            while IFS= read -r -d '' file; do
                if [[ -f "$file" && ! -L "$file" && "/$file" != */__pycache__/* ]]; then
                    count=$((count + 1))
                fi
            done < <(find "./$dir" -type f -print0)
        fi

        printf '%d %s\n' "$count" "$dir"
    done | sort -nr
}

folder_count "$@"
