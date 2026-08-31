#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/update-flake-package.sh" hermes-agent hermes-agent-desktop
