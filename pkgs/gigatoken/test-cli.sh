#!/usr/bin/env bash
set -euo pipefail

gigatoken_bin="$1"
tokenizer="$2"

actual="$(printf 'hello' | "$gigatoken_bin" count --tokenizer "$tokenizer")"
if [[ "$actual" != 1 ]]; then
  printf 'expected count output 1, got %q\n' "$actual" >&2
  exit 1
fi

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
printf 'hello' >"$test_dir/one.txt"
printf 'hello world' >"$test_dir/two.txt"
printf 'ignored' >"$test_dir/ignored.log"

actual="$("$gigatoken_bin" count --tokenizer "$tokenizer" --exclude '*.log' "$test_dir")"
if [[ "$actual" != 3 ]]; then
  printf 'expected directory count output 3, got %q\n' "$actual" >&2
  exit 1
fi

actual="$("$gigatoken_bin" encode --tokenizer "$tokenizer" --json hello)"
if [[ "$actual" != '[31373]' ]]; then
  printf 'expected encoded token [31373], got %q\n' "$actual" >&2
  exit 1
fi

actual="$("$gigatoken_bin" decode --tokenizer "$tokenizer" 31373)"
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
