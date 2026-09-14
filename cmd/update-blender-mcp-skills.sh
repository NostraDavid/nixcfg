#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/update-flake-package.sh" blender-mcp-skills blender-mcp-skills
