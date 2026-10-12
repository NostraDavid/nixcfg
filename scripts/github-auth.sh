#!/usr/bin/env bash
# Source before GitHub API requests, including Nix flake operations.

if [[ -z "${GITHUB_TOKEN:-}" ]] && command -v gh >/dev/null 2>&1 && github_token="$(gh auth token 2>/dev/null)"; then
    export GITHUB_TOKEN="${github_token}"
fi
unset github_token
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    export NIX_CONFIG="${NIX_CONFIG:-}"$'\n'"extra-access-tokens = github.com=${GITHUB_TOKEN}"
fi
