---
name: new-repo
description: Bootstrap new NostraDavid repositories, or apply their repository baseline on request, with Just, Nix, prek, locked dependencies, and quality gates. Exclude ordinary feature work and unrelated repositories.
---

# New NostraDavid repo

Build a working local repository foundation with one developer interface and
reproducible checks. Preserve an existing project's language and layout. For a
new project without a chosen stack, use Python with uv, Ruff, ty, and pytest.
Create application behavior only when the user requests it.

## Establish the target

1. Identify the directory, project purpose, language, and current Git state.
   Inspect existing manifests, commands, hooks, and instructions before editing.
   Use the current checkout, including when it is named `trunk`. Preserve
   unrelated work. Initialize an empty personal repository on `master` unless
   the user selected another branch. Use isolated worktrees when concurrent
   writers would otherwise share a checkout.
2. Carry out local setup using the available context. Ask only for choices that
   block useful work. Keep unresolved license, remote visibility, credentials,
   and production decisions explicit. Local setup does not authorize publishing,
   pushing, deploying, or accepting data loss.
3. Read [tooling.md](references/tooling.md) before creating the foundation. Read
   [project-decisions.md](references/project-decisions.md) to classify each
   architecture area as applicable or deferred. Include every area in the
   repository's baseline decision record, with its reason and review trigger.

## Create the common foundation

Every repository needs:

- An executable root `Justfile`, with grouped commands and a default that runs
  `just --list --unsorted`. All developer-facing operations enter through Just.
- A Nix flake and committed `flake.lock`. Provide a development shell for the
  supported Linux and macOS systems. A root flake is the new-repo default;
  preserve a documented existing `nix/flake.nix` layout when adopting the
  baseline.
- `.pre-commit-config.yaml` for prek. Use `repo: local`, `language: system`, and
  Just recipes as hook entries. Use a verified shared hook dispatcher or install
  a repository-local hook. Preserve unrelated hooks and global Git settings. CI,
  when present, calls the same Just gates.
- A mandatory gitinclude-style `.gitignore`, a useful README, and a concise
  `AGENTS.md`. Ignore all root paths by default, then explicitly allow source,
  tests, documentation, manifests, and locks. Keep runtime state, secrets,
  environments, caches, and generated output ignored.
- Repository-local formatter and quality configuration. Use dprint for supported
  text/configuration formats, plus the language's formatter, linter, type
  checker, test runner, and dependency audit. Select only tools the project
  needs.
- Locked language dependencies. Normal sync, checks, and execution must preserve
  lockfiles; dependency upgrades are separate, explicit operations.
- `docs/adr/` and a short `docs/project-baseline.md`. Record actual decisions,
  applicable architecture rules, deferred areas, and commands that were
  verified. Create ADRs for material choices rather than one document per
  checklist item.

Offer direnv through a reviewed `.envrc`; entering the shell must not start
services. The README must explain how to enter the shell and run `just setup`.
Never require production credentials to run the local quality gates.

`AGENTS.md` names the canonical commands, relevant documentation, and project
invariants. Reference `~/.agents/instructions/shared.md` when available. Keep
machine-specific paths and copied global instruction collections out of it.

## Keep one command contract

| Recipe         | Required behavior                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------------------ |
| `setup`        | Synchronize locked dependencies and prepare the repository's active prek gate.                         |
| `sync`         | Recreate the selected language environment from its lockfile.                                          |
| `format`       | Format all maintained source and configuration formats.                                                |
| `format-check` | Check the same files without rewriting them.                                                           |
| `lint`         | Run the project's configured static checks.                                                            |
| `type-check`   | Check the actual project environment when the stack supports it.                                       |
| `test`         | Run existing unit and local integration tests without live external APIs.                              |
| `audit-all`    | Audit every applicable project/script dependency graph; fail on findings or unavailable audit results. |
| `check`        | Run the applicable read-only quality gates, including lock/flake validation and dependency audits.     |
| `pre-commit`   | Run prek against all tracked files; keep it out of `check` to avoid recursion.                         |
| `lock-upgrade` | Explicitly upgrade language dependencies, separately from normal sync.                                 |
| `update-nix`   | Explicitly refresh the flake lockfile for review.                                                      |
| `changelog`    | Report changes between supplied commits, with a documented default baseline.                           |

Adapt recipe implementations to the chosen stack. Add monitoring, contracts,
database, build, and runtime recipes only when their capabilities exist. Each
recipe must execute real checks or work. Empty test suites and missing tools
must remain visible; do not replace them with passing stubs or invent product
features to manufacture a green test gate. Add focused regression tests when an
observed defect establishes the behavior to protect.

For managed services, keep Just as the human interface and one project-owned
`./dev` entrypoint for lifecycle operations. A Python runtime controller uses a
thin executable wrapper and a uv-managed `dev.py`; it coordinates services and
keeps business logic in the owning programs or libraries.

## Verify the foundation

1. Generate real lockfiles with the selected tools. Make new flake sources
   visible to Nix's Git source filter using explicit-path intent-to-add when
   needed. Do not stage unrelated files or create a commit without
   authorization.
2. Enter the pinned shell and inspect `just --list --unsorted`. Run
   `just setup`, `prek validate-config .pre-commit-config.yaml`, formatting,
   `just check`, and `just pre-commit`. A "No configs to check" result does not
   validate the hook. Verify the installed Git hook, not only the configuration
   file. An audit may need network access; unit/integration tests must remain
   local by default.
3. Check `git status` and `git check-ignore`: an unlisted root file and
   directory must stay ignored. All intended source/configuration and lockfiles
   must be includable, while secrets and runtime data stay ignored. Inspect the
   diff for names, paths, copied credentials, and unfinished stubs.
4. Evaluate every declared flake system with `--all-systems --no-build`. Verify
   each claimed platform separately. Flake evaluation is not proof of a
   successful build or runtime on another OS. When a live service was requested,
   test startup, readiness, targeted restart, and shutdown using temporary
   state.
5. Report created/changed files, actual gate results, architecture decisions,
   deferred areas, and remaining prerequisites. Distinguish completed local
   setup from publication or deployment.
