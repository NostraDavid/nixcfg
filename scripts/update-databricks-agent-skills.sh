#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/update-flake-package.sh" databricks-agent-skills databricks-agent-skills
