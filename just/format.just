# Format all Nix files in the repository.
format-alejandra:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty alejandra

format-dprint:
  @dprint fmt . --excludes dev.code-workspace docs/agentskills.io dotfiles/copilot-1.0/.copilot/copilot-instructions.md

format-shfmt:
  @git ls-files -z -- '*.sh' ':(glob)**/.bashrc' ':(glob)**/.bash_aliases' | xargs -0 --no-run-if-empty shfmt -i 4 -w

format-stylua:
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty stylua

format-ruff:
  @git ls-files -z -- '*.py' 'dotfiles/git/.config/git/hooks/commit-msg' | grep -zEv '^dotfiles/agents/\.agents/' | xargs -0 --no-run-if-empty ruff format

format:
  @just format-alejandra
  @just format-dprint
  @just format-shfmt
  @just format-stylua
  @just format-ruff

fmt:
  @just format

# Run formatting checks without modifying files.
check:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty alejandra --check
  @dprint check . --excludes dev.code-workspace docs/agentskills.io dotfiles/copilot-1.0/.copilot/copilot-instructions.md
  @git ls-files -z -- '*.sh' ':(glob)**/.bashrc' ':(glob)**/.bash_aliases' | xargs -0 --no-run-if-empty shfmt -i 4 -d
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty stylua --check
  @git ls-files -z -- '*.py' 'dotfiles/git/.config/git/hooks/commit-msg' | grep -zEv '^dotfiles/agents/\.agents/' | xargs -0 --no-run-if-empty ruff format --check

check-alejandra-files *files:
  @alejandra --check {{files}}

check-dprint-files *files:
  @dprint check --allow-no-files {{files}}

check-shfmt-files *files:
  @printf '%s\0' {{files}} | xargs -0 --no-run-if-empty shfmt -i 4 -d

check-stylua-files *files:
  @stylua --check {{files}}

check-ruff-format-files *files:
  @printf '%s\0' {{files}} | { grep -zEv '^dotfiles/agents/\.agents/' || true; } | xargs -0 --no-run-if-empty ruff format --check
