#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/update-flake-package.sh" blender-reference-skills blender-reference-skills
