[group('lint')]
hooks-run:
  @prek --config .pre-commit-config.yaml run --all-files

# Validate managed agent skills, shared references, and Home Manager links.
[group('lint')]
check-agent-instructions:
  @{{nix_clean_env}} nix build 'path:.#checks.x86_64-linux.agent-instructions' --no-link

[group('lint')]
lint-ruff:
  @git ls-files -z -- '*.py' 'dotfiles/git-2.49.0/.config/git/hooks/commit-msg' | grep -zEv '^dotfiles/agents/\.agents/' | xargs -0 --no-run-if-empty ruff check

[group('lint')]
lint-ruff-files *files:
  @printf '%s\0' {{files}} | { grep -zEv '^dotfiles/agents/\.agents/' || true; } | xargs -0 --no-run-if-empty ruff check

[group('lint')]
lint-shellcheck:
  @git ls-files -z -- '*.sh' '.bashrc' '.bash_aliases' | xargs -0 --no-run-if-empty shellcheck --severity=error

[group('lint')]
lint-shellcheck-files *files:
  @printf '%s\0' {{files}} | xargs -0 --no-run-if-empty shellcheck --severity=error

[group('lint')]
lint-markdown:
  @git ls-files -z -- '*.md' | grep -zEv '^(docs/agentskills\.io/|dotfiles/agents/\.agents/)' | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

[group('lint')]
lint-markdown-files *files:
  @printf '%s\0' {{files}} | { grep -zEv '^dotfiles/agents/\.agents/' || true; } | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

[group('lint')]
lint-selene:
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty selene

[group('lint')]
lint-selene-files *files:
  @selene {{files}}

[group('lint')]
lint-statix:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty -n1 statix check

[group('lint')]
lint-statix-files *files:
  @for file in {{files}}; do statix check "$file"; done

[group('lint')]
lint-deadnix:
  @git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty deadnix --fail

[group('lint')]
lint-deadnix-files *files:
  @deadnix --fail {{files}}

[group('lint')]
lint:
  @just check-agent-instructions
  @just lint-ruff
  @just lint-shellcheck
  @just lint-markdown
  @just lint-selene
  @just lint-statix
  @just lint-deadnix

[group('lint')]
precommit:
  @just hooks-run

[group('lint')]
versions:
  @printf '%-14s %s\n' 'ruff:' "$(if command -v ruff >/dev/null 2>&1; then ruff --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'shellcheck:' "$(if command -v shellcheck >/dev/null 2>&1; then shellcheck --version | awk 'NR==2 {print $2; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'markdownlint:' "$(if command -v markdownlint >/dev/null 2>&1; then markdownlint --version; else echo missing; fi)"
  @printf '%-14s %s\n' 'stylua:' "$(if command -v stylua >/dev/null 2>&1; then stylua --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'selene:' "$(if command -v selene >/dev/null 2>&1; then selene --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'lua-ls:' "$(if command -v lua-language-server >/dev/null 2>&1; then lua-language-server --version 2>&1 | awk 'NR==1 {print $NF; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'statix:' "$(if command -v statix >/dev/null 2>&1; then echo installed; else echo missing; fi)"
  @printf '%-14s %s\n' 'deadnix:' "$(if command -v deadnix >/dev/null 2>&1; then deadnix --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'alejandra:' "$(if command -v alejandra >/dev/null 2>&1; then alejandra --version | awk '{print $2}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'dprint:' "$(if command -v dprint >/dev/null 2>&1; then dprint --version | awk '{print $2; exit}'; else echo missing; fi)"
  @printf '%-14s %s\n' 'shfmt:' "$(if command -v shfmt >/dev/null 2>&1; then shfmt --version; else echo missing; fi)"
  @printf '%-14s %s\n' 'prek:' "$(if command -v prek >/dev/null 2>&1; then prek -V | awk '{print $2}'; else echo missing; fi)"
