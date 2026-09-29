#!/usr/bin/env bash
set -euo pipefail

gigatoken_bin="$1"

actual="$(printf "You're testing GPT-5's tokenizer: 1234567 👋" | "$gigatoken_bin" count)"
if [[ "$actual" != 14 ]]; then
    printf 'expected default GPT-5 count output 14, got %q\n' "$actual" >&2
    exit 1
fi

actual="$(printf 'hello' | "$gigatoken_bin" count)"
if [[ "$actual" != 1 ]]; then
    printf 'expected count output 1, got %q\n' "$actual" >&2
    exit 1
fi

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
printf 'hello' >"$test_dir/one.txt"
printf 'hello world' >"$test_dir/two.txt"
printf 'ignored' >"$test_dir/ignored.log"

actual="$("$gigatoken_bin" count --exclude '*.log' "$test_dir")"
if [[ "$actual" != 3 ]]; then
    printf 'expected directory count output 3, got %q\n' "$actual" >&2
    exit 1
fi

encoded="$("$gigatoken_bin" encode --json hello)"
if [[ "$encoded" != \[*\] ]]; then
    printf 'expected encoded JSON array, got %q\n' "$encoded" >&2
    exit 1
fi

actual="$(printf '%s' "$encoded" | "$gigatoken_bin" decode)"
if [[ "$actual" != hello ]]; then
    printf 'expected decoded text hello, got %q\n' "$actual" >&2
    exit 1
fi

help_output="$("$gigatoken_bin" --help)"
for command in count encode decode bench; do
    if [[ "$help_output" != *"$command"* ]]; then
        printf 'expected top-level help to mention %s\n' "$command" >&2
        exit 1
    fi
done

"$gigatoken_bin" bench --help >/dev/null
