#!/usr/bin/env bash
set -euo pipefail

rules="$(dirname -- "$(readlink -f -- "$0")")/piper.sed"
input='nixcfg scoped message. unscoped nixcfgx messages xmessage.'
expected=$'niks config [[sk\u02c8oʊpd]] [[m\u02c8ɛsɪdʒ]]. unscoped nixcfgx messages xmessage.'
actual=$(printf '%s\n' "$input" | sed -f "$rules")
[[ "$actual" == "$expected" ]]
printf 'Piper-uitspraakregels en woordgrenzen: OK\n'
