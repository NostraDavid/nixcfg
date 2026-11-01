---
name: gitignore
description: Use for any request to create, update, or review a .gitignore file. Apply repository-root allowlists; keep nested ignore files scoped to local generated content.
---

# Gitignore files

Keep ignore rules deliberate and scoped. Repository roots use an allowlist;
nested `.gitignore` files stay focused on generated files local to their
directory. Preserve existing rules and unrelated work.

## Establish scope

1. Read repository instructions and inspect the current `.gitignore` files,
   tracked paths, generated output, and `git status` before editing.
2. Treat a root `.gitignore` as repository policy. Ignore root entries first,
   then allow only maintained files and directories. Re-include every parent
   directory required to reach an allowed nested file.
3. Keep nested `.gitignore` files minimal. Git interprets their patterns
   relative to the directory containing the file; do not turn a local log or
   cache rule into a repository-wide allowlist.

## Write a root allowlist

Use root-anchored allow rules. Inspect each allowed directory before reopening
it: allowing a directory also allows its contents unless later patterns exclude
them. Re-ignore secrets, environments, caches, build output, and runtime data
inside allowed directories. Adapt this example to files that actually exist:

```gitignore
# ignore all direct items, nonrecursively
/*

# unignore folders (ordered by when added)
!.github/
!docs/
!dotfiles/
!hosts/
!users/
!home/
!modules/
!features/
!profiles/
!nix/
!policy/
!pkgs/
!programs/
!infra/
!infra/**/*.tf
!infra/**/*.md
!infra/**/*.example
!infra/freeipa/*.toml
!infra/**/.terraform.lock.hcl
!src/
!tests/
!Justfile
!just/
!.vscode/settings.json
!scripts/
!checks/
!codd/

# unignore files (ordered by when added)
!.gitignore
!.envrc
!flake.lock
!flake.nix
!pyproject.toml
!uv.lock
!.pre-commit-config.yaml
!stylua.toml
!selene.toml
!ruff.toml
!vim.yml
!README.md
!AGENTS.md
!huisplan.md
!nixstory.md
!.gitattributes

# reignore recursively (ordered by when added)
**/.direnv/
**/.env
**/.env.*
**/.venv/
**/node_modules/
**/var/
__pycache__/
*.egg-info/
```

Allow a public environment example only after reviewing its contents. Add
project-specific generated directories and credential formats deliberately.
Use `git check-ignore --no-index -v` to inspect both allowed source paths and
representative secrets or generated paths.

## Generate and verify

The bundled `scripts/generate_gitignore.py` command inventories direct directory
entries, including dotfiles, and renders root-anchored allow rules. It omits
`.git` metadata and treats directory symlinks as files. Its output is an
inventory, not a security policy: it allows every discovered direct file and
directory, so review every rule and add exclusions before using it in a real
repository. Preview first:

```sh
generate_gitignore generate --directory /path/to/repository --dry-run
```

Use `--yes` only after reviewing the output. The `check` command checks
filesystem readiness, not whether ignore rules are correct. The existing
`generate_gitignore` command remains available through NDTK.

After editing, test paths that must be included and ignored with Git, inspect
the changed `.gitignore` files, and run `git diff --check`. Keep any existing
repository-specific exclusions that remain valid.
