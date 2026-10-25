# Repository tooling

Use these patterns to write configuration for the actual project. Adapt the
commands to its language and directory layout. Generate fresh locks; choose
compatible versions instead of copying another project's dependency snapshot.

## Nix and environments

Keep Nix responsible for developer executables and native infrastructure.
Language dependencies belong to their native lockfile. Start new repositories
with a root flake, and support these systems where their dependencies permit:

```nix
{
  description = "Repository development tools";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = {nixpkgs, ...}: let
    systems = ["x86_64-linux" "aarch64-linux" "aarch64-darwin"];
    eachSystem = nixpkgs.lib.genAttrs systems;
  in {
    devShells = eachSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [git just prek dprint nixfmt uv python3 ruff ty];
      };
    });
    formatter = eachSystem (system: nixpkgs.legacyPackages.${system}.nixfmt);
  };
}
```

The package list above is for Python. Replace language-specific entries for
other stacks. Pin `flake.lock`, check the selected interpreter version, and set
the language manifest's supported versions accordingly. Document platform guards
and unavailable tools. Resolve dependency incompatibilities using compatible
packages; preserve the checks that expose them.

The matrix above covers the common Linux targets and Apple Silicon macOS. Add
Intel macOS only with a nixpkgs revision that supports `x86_64-darwin`. Evaluate
every declared target; do not infer platform support from the native shell
succeeding.

When Nix supplies Python, set the interpreter preference in the project's
`pyproject.toml` so user-level uv settings cannot exclude that interpreter:

```toml
[tool.uv]
python-preference = "only-system"
```

Use the selected Nix interpreter when generating and synchronizing the lockfile.
Keep global uv settings unchanged. Preserve an existing project's explicit
runtime-management choice when adopting the baseline.

Use `.envrc` with `use flake` for a root flake. A nested flake uses
`use flake ./nix`. Keep service startup explicit. Do not install project tools
globally or hardcode Nix store paths in project/editor configuration.

## Just and prek

The first line of `Justfile` is `#!/usr/bin/env -S just --justfile`; set its
executable bit. Use strict Bash and positional argument forwarding. In Python
repositories, remove Nix or surrounding virtualenv state before invoking uv:

```just
#!/usr/bin/env -S just --justfile

set shell := ["bash", "-euo", "pipefail", "-c"]
set positional-arguments

unexport PYTHONPATH
unexport PYTHONHOME
unexport VIRTUAL_ENV
unexport _PYTHON_SYSCONFIGDATA_NAME

[group('repository')]
default:
    @just --list --unsorted

[group('repository')]
setup: sync
    prek install

[group('dependencies')]
sync:
    uv sync --locked --all-groups --python python3 --no-python-downloads

[group('dependencies')]
lock-upgrade:
    uv lock --upgrade --python python3 --no-python-downloads

[group('dependencies')]
update-nix:
    nix flake update

[group('quality')]
check: format-check lint type-check test flake-check audit-all

[group('quality')]
format:
    ruff format --force-exclude .
    dprint fmt --config dprint.json --config-discovery=false
    just --fmt --unstable
    nixfmt flake.nix

[group('quality')]
format-check:
    ruff format --check --force-exclude .
    dprint check --config dprint.json --config-discovery=false
    just --fmt --check --unstable
    nixfmt --check flake.nix

[group('quality')]
lint:
    ruff check --force-exclude .

[group('quality')]
type-check: sync
    ty check --python .venv

[group('quality')]
test: sync
    uv run --locked python -m pytest

[group('quality')]
flake-check:
    nix flake check --all-systems --no-build --no-write-lock-file

[group('quality')]
audit-all:
    uv audit --locked

[group('quality')]
pre-commit:
    prek run --config .pre-commit-config.yaml --all-files

[group('repository')]
changelog baseline="HEAD^" target="HEAD":
    git log --format='%h %s' "$1..$2"
```

The flake gate evaluates every declared system without attempting cross-builds.
If the project defines Nix checks or distributable packages, add the appropriate
native build/check gate too. An evaluation pass alone does not test their
runtime.

This example assumes one root Python project, a root flake, a generated
`dprint.json`, and default Git hook discovery. Inspect
`git config --path --get
core.hooksPath` before choosing the actual setup
recipe. A shared dispatcher that already runs prek for this directory needs
`prek validate-config .pre-commit-config.yaml` and hook preparation rather than
`prek install`. Verify the dispatcher's path conditions. Preserve an unrelated
hook and report a concrete conflict rather than forcing installation or changing
global configuration.

Add all maintained Nix files to both formatting recipes as the project grows. A
new repository without a parent commit needs an explicit changelog baseline;
document that boundary.

For a multi-project repository, discover the actual manifests and use each
project's own locked environment for sync, type checks, tests, audit, and
upgrades. Avoid importing a sibling project through accidental `PYTHONPATH`
settings. Use local editable package sources for shared libraries.

For standalone PEP 723 scripts, declare and pin their dependencies, generate
their script lockfiles, audit those graphs too, and expose them through Just. Do
not add an orchestration script for a single command that Just already runs.

Start prek with one canonical local gate:

```yaml
default_stages: [pre-commit]
fail_fast: true
repos:
  - repo: local
    hooks:
      - id: check
        name: Repository quality gates
        entry: just check
        language: system
        pass_filenames: false
        always_run: true
```

Run commits and hooks inside the pinned development environment. Split hooks by
affected paths only when needed, with every entry still calling a Just recipe.
Keep repository-wide dependency audits active on every commit. A specialized
external hook requires a pinned revision and a recorded reason.

`check` must not call `pre-commit`, `format`, dependency upgrades, cleanup, or
service startup. CI must enter the same pinned environment and run the same
gates when CI is requested or already configured. Publishing requires its own
scope.

## Formatting and lock policy

Generate a local `dprint.json` with exact, verified plugin versions for the file
types present: Markdown, JSON/JSONC, TOML, YAML, and any frontend languages.
Ruff owns Python formatting; nixfmt owns Nix; Just owns its own formatting.
Exclude `var/`, `.direnv/`, `.venv/`, `node_modules/`, build output, and
generated lockfiles from generic formatting. Add frontend tests to `just test`
when frontend behavior exists; use Node's native test runner when sufficient.

Normal commands use locked installs, such as `uv sync --locked` or `npm ci`.
Upgrade one selected dependency graph at a time and review its lock diff. Audit
failures and unavailable audit results fail the gate. Resolve the dependency,
apply a demonstrated mitigation, or record an explicit owner-approved exception;
do not turn the failure into a passing check. Add Nix closure scanning when the
project actually exposes distributable Nix packages.

## Gitinclude-style allowlist

Every repository must use gitinclude style: ignore all root paths first, then
re-include maintained files and directories explicitly. Re-ignore generated
content and secrets inside allowed directories. Adapt this required pattern to
the real source layout:

```gitignore
/*
!/.gitignore
!/AGENTS.md
!/README.md
!/Justfile
!/flake.nix
!/flake.lock
!/.envrc
!/.pre-commit-config.yaml
!/dprint.json
!/pyproject.toml
!/uv.lock
!/src/
!/tests/
!/docs/

**/.venv/
**/__pycache__/
**/*.egg-info/
**/node_modules/
**/.direnv/
**/.env
**/.env.*
**/var/
```

Re-include parent directories for nested maintained files. Add required project
directories and manifests deliberately, including `scripts/`, `nix/`, a CI
directory, editor configuration, `dev`, `dev.py`, and `dev.py.lock` only when
they exist. Inspect files before allowing a directory that already has content.
Keep generated credentials, logs, databases, caches, and large data out of Git.
Use `git check-ignore --no-index -v` on representative source and secret paths.

## Repository instructions and decisions

The README covers purpose, prerequisites, shell entry, setup, quality gates,
normal execution, dependency updates, supported systems, and local state. Keep
`AGENTS.md` short: shared instructions when available, canonical commands,
relevant ADR/runbook links, and project-specific invariants. Use one canonical
instruction document if an agent-specific filename is also required.

Create `docs/project-baseline.md` with a small disposition table for every area
in `project-decisions.md`: applied, not applicable, or deferred, with a reason
and a review trigger. Record material choices in `docs/adr/` with stable IDs,
status, context, decision, and consequences. Respect an existing ADR format. Do
not copy another project's ADR identifiers, history, names, or domain model.

Commits use `<scope>: <description>`. Application deployment identity is the Git
commit SHA; generate changelogs between selected commits. A library or protocol
may still need compatibility versions. Add license text only after the license
is known. Keep remote creation, visibility, branch protection, publication, and
deployment within the user's explicit request.
