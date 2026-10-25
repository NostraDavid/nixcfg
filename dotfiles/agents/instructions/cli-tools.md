# Agent-usable CLI tools

This is a short index of profile tools useful for code, data, builds, and
verification, plus the host's `nix` command. It leaves out editors, terminal
multiplexers, GUI apps, and niche utilities. Use `command -v NAME` to check
whether a command is on this host.

`portable-cli` is the default for Mimir2 and Loki. NixOS `workstation-base` adds
the `development`, `terminal`, `containers`, and `media` profiles; development
also includes the portable development core. The optional Home Manager
`workstation` module adds its own development and CLI tools. `full-workstation`
adds the lab and media-production tools.

The shared profiles include `nix-index`, `nvd`, `nix-tree`, `actionlint`,
`lnav`, and `watchexec` on all six physical hosts after activation.

## Find and change code

- `rg` and `git grep` for exact text; `fd` for paths; `ast-grep` for structural
  search and rewrite previews; `tree-sitter` for queries with a configured
  grammar. Use `fzf` to select results and `sd` to replace text.
- `probe` for ranked code discovery, symbol outlines, and AST extraction;
  Universal Ctags (`ctags`) for definitions, `cloc` for language counts, and
  `lizard` for function complexity and duplicate analysis. The shared
  `code-navigation` aspect supplies these tools on all six physical hosts.
- `semble` for semantic code search on x86_64 Linux. Use Probe and `rg` where
  Semble is unavailable. Read [code-navigation.md](code-navigation.md) for the
  tool selection workflow. These CLI commands run on demand.
- `features/code-navigation/` owns directly invoked terminal navigation tools.
  Language servers and editor extensions stay with the development and editor
  tooling. Semble stays limited to x86_64 Linux.
- `git`, `jj`, `git-lfs`, `mergiraf`, `delta`, `difftastic`, and `riffdiff` for
  source control and diffs.
- `just`, `devenv`, `direnv`, `uv`, and `node`/`npm`/`npx` for project tasks.
- `watchexec` to rerun commands after file changes. Use an existing project
  watcher when one already handles the task.

## Inspect Nix packages

- `nix-locate` from `nix-index` to find which package provides a binary or
  library when the package name is unknown.
- `nvd` to compare package versions between Nix closures or system generations.
- `nix-tree` to explore closure sizes and dependency paths interactively.

Home Manager activation runs `nix-index` when its database is missing or empty.
It preserves an existing index. The first build needs internet access and uses
the pinned unstable nixpkgs for the host platform. The database directory is
`NIX_INDEX_DATABASE`, otherwise `$XDG_CACHE_HOME/nix-index`, falling back to
`~/.cache/nix-index`. Run `nix-index` explicitly only when a rebuild is needed.

## Inspect structured data

- `mlr` (Miller), `csvkit`, `jq`, `xmllint`, `xq`, `yq`, `duckdb`, `sqlite3`,
  and `zsv` are in the NixOS terminal profile.
- The workstation add-on adds `kcat`, `parquet-tools`, `xan`, and `psql`.
- For global file lookup, use `locate` or `plocate`; inside a repository, prefer
  `rg`.
- After activating the per-user plocate configuration, run `updatedb` without
  `sudo` when the index is missing or stale. Both search commands use the same
  private database, normally `~/.cache/plocate/plocate.db`.

The user measured `sudo time updatedb` on Wodan at 37.66 seconds elapsed, 25.33
seconds user CPU and 12.16 seconds system CPU. Budget about a minute for an
update and allow longer runs to finish. This privileged scan is a reference; the
per-user scan and other machines can take a different amount of time.

## Build and verify

- Nix: `nix`, `home-manager`, `nix-update`, `alejandra`, `deadnix`,
  `nixf-diagnose`, and `statix`; the workstation add-on also has `nixfmt`.
- Shell/Python/JS: `shellcheck`, `shfmt`, `ruff`, `pyrefly`, `ty`, `oxlint`,
  `dprint`, `markdownlint`, and `prek`.
- `actionlint` to check GitHub Actions workflows, expressions, and embedded
  shell code with ShellCheck.
- Other toolchains as needed: `gcc`, `go`, `gofumpt`, `java`; the workstation
  add-on adds `cargo`, `clang`, `gradle`, `rubocop`, and `zig`.
- Security scans: `grype`, `osv-detector`, `osv-scanner`, `sbomnix`, `syft`, and
  `vulnix`.

## Agent and task support

- `lnav` to filter and query logs. For a single error, use `journalctl` or `rg`.
- Context/output: `ctx`, `ctx7`, `headroom`, `agent-memory`, `engram`, `engrim`,
  `rtk`, and `snip`; `mcporter` is in `portable-cli`.
- Other installed coding-agent CLIs: `codex`, `copilot`, `opencode`, and `pi`;
  invoke only when a task calls for them.
- Infrastructure tasks: `podman`, `podman-compose`, `kubectl`, `helm`, `tofu`,
  `k3d`, and `k3s`.
- PDF/media tasks: `pdftotext`, `pdfinfo`, `pdftoppm`, `ffmpeg`, `magick`, and
  `yt-dlp`. Workstation Linux data tools include `cdo`, `gdal`, `h5utils`,
  `nco`, and `netcdf`.
