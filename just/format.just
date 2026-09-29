# Format all Nix files in the repository.
[group('format')]
format-alejandra:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty alejandra

[group('format')]
format-dprint:
  @dprint fmt . --excludes dev.code-workspace docs/agentskills.io dotfiles/copilot-1.0.65/.copilot/copilot-instructions.md

[group('format')]
format-shfmt:
  @git ls-files -z -- '*.sh' ':(glob)**/.bashrc' ':(glob)**/.bash_aliases' | xargs -0 --no-run-if-empty shfmt -i 4 -w

[group('format')]
format-stylua:
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty stylua

[group('format')]
format-ruff:
  @git ls-files -z -- '*.py' 'dotfiles/git-2.49.0/.config/git/hooks/commit-msg' | grep -zEv '^dotfiles/agents/\.agents/' | xargs -0 --no-run-if-empty ruff format

[group('format')]
format:
  @just format-alejandra
  @just format-dprint
  @just format-shfmt
  @just format-stylua
  @just format-ruff

[group('format')]
fmt:
  @just format

# Run formatting checks without modifying files.
[group('format')]
check:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty alejandra --check
  @dprint check . --excludes dev.code-workspace docs/agentskills.io dotfiles/copilot-1.0.65/.copilot/copilot-instructions.md
  @git ls-files -z -- '*.sh' ':(glob)**/.bashrc' ':(glob)**/.bash_aliases' | xargs -0 --no-run-if-empty shfmt -i 4 -d
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty stylua --check
  @git ls-files -z -- '*.py' 'dotfiles/git-2.49.0/.config/git/hooks/commit-msg' | grep -zEv '^dotfiles/agents/\.agents/' | xargs -0 --no-run-if-empty ruff format --check

[group('format')]
check-alejandra-files *files:
  @alejandra --check {{files}}

[group('format')]
check-dprint-files *files:
  @dprint check --allow-no-files {{files}}

[group('format')]
check-shfmt-files *files:
  @printf '%s\0' {{files}} | xargs -0 --no-run-if-empty shfmt -i 4 -d

[group('format')]
check-stylua-files *files:
  @stylua --check {{files}}

[group('format')]
check-ruff-format-files *files:
  @printf '%s\0' {{files}} | { grep -zEv '^dotfiles/agents/\.agents/' || true; } | xargs -0 --no-run-if-empty ruff format --check
