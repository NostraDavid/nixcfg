#!/usr/bin/env bash

main() {
    local sort_flag=0 sort_desc_flag=0 arg total=0 file count tmpfile

    for arg in "$@"; do
        case "$arg" in
        --sort) sort_flag=1 ;;
        --sort-desc | --desc)
            sort_flag=1
            sort_desc_flag=1
            ;;
        --help | -h)
            echo "Usage: pylc [--sort] [--sort-desc]"
            return 0
            ;;
        *)
            echo "pylc: unknown option '$arg'"
            echo "Try: pylc --sort --sort-desc"
            return 2
            ;;
        esac
    done

    command -v find >/dev/null 2>&1 || {
        echo 'find is not installed.' >&2
        return 1
    }
    command -v mktemp >/dev/null 2>&1 || {
        echo 'mktemp is not installed.' >&2
        return 1
    }
    command -v sort >/dev/null 2>&1 || {
        echo 'sort is not installed.' >&2
        return 1
    }

    tmpfile=$(mktemp) || {
        echo 'pylc: mktemp failed' >&2
        return 1
    }

    while IFS= read -r -d '' file; do
        count=$(wc -l <"$file") || count=0
        printf '%d\t%s\n' "$count" "$file" >>"$tmpfile"
        total=$((total + count))
    done < <(
        find . -type d -name src -print0 | while IFS= read -r -d '' dir; do
            find "$dir" -type f -name '*.py' \
                ! -path '*/venv/*' \
                ! -path '*/.venv/*' \
                ! -path '*/__pycache__/*' -print0
        done
    )

    if ((sort_flag)); then
        if ((sort_desc_flag)); then
            sort -t $'\t' -k1,1nr "$tmpfile" -o "$tmpfile" || {
                rm -f "$tmpfile"
                return 1
            }
        else
            sort -t $'\t' -k1,1n "$tmpfile" -o "$tmpfile" || {
                rm -f "$tmpfile"
                return 1
            }
        fi
    fi

    while IFS=$'\t' read -r count file; do
        printf '%6d %s\n' "$count" "$file"
    done <"$tmpfile"
    rm -f "$tmpfile"
    printf '%s\n%6d %s\n' '------' "$total" TOTAL
}

main "$@"
