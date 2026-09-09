hooks-run:
  @prek --config .pre-commit-config.yaml run --all-files

lint-ruff:
  @git ls-files -z -- '*.py' 'dotfiles/git/.config/git/hooks/commit-msg' | grep -zEv '^dotfiles/agents/\.agents/' | xargs -0 --no-run-if-empty ruff check

lint-ruff-files *files:
  @printf '%s\0' {{files}} | { grep -zEv '^dotfiles/agents/\.agents/' || true; } | xargs -0 --no-run-if-empty ruff check

lint-shellcheck:
  @git ls-files -z -- '*.sh' '.bashrc' '.bash_aliases' | xargs -0 --no-run-if-empty shellcheck --severity=error

lint-shellcheck-files *files:
  @printf '%s\0' {{files}} | xargs -0 --no-run-if-empty shellcheck --severity=error

lint-markdown:
  @git ls-files -z -- '*.md' | grep -zEv '^(docs/agentskills\.io/|dotfiles/agents/\.agents/)' | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

lint-markdown-files *files:
  @printf '%s\0' {{files}} | { grep -zEv '^dotfiles/agents/\.agents/' || true; } | xargs -0 --no-run-if-empty markdownlint --disable MD013 MD040 MD041 --

lint-selene:
  @git ls-files -z -- '*.lua' | xargs -0 --no-run-if-empty selene

lint-selene-files *files:
  @selene {{files}}

lint-statix:
  @cmd=(statix check); \
  if ! command -v statix >/dev/null 2>&1; then cmd=(nix develop --command statix check); fi; \
  git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty -n1 "${cmd[@]}"

lint-statix-files *files:
  @cmd=(statix check); \
  if ! command -v statix >/dev/null 2>&1; then cmd=(nix develop --command statix check); fi; \
  for file in {{files}}; do "${cmd[@]}" "$file"; done

lint-deadnix:
  @cmd=(deadnix --fail); \
  if ! command -v deadnix >/dev/null 2>&1; then cmd=(nix develop --command deadnix --fail); fi; \
  git ls-files -z -- '*.nix' | xargs -0 --no-run-if-empty "${cmd[@]}"

lint-deadnix-files *files:
  @cmd=(deadnix --fail); \
  if ! command -v deadnix >/dev/null 2>&1; then cmd=(nix develop --command deadnix --fail); fi; \
  "${cmd[@]}" {{files}}

lint:
  @just lint-ruff
  @just lint-shellcheck
  @just lint-markdown
  @just lint-selene
  @just lint-statix
  @just lint-deadnix

precommit:
  @just hooks-run

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
