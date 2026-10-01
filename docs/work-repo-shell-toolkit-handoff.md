# Handoff for work nixcfg: Bash and NDTK

Use this handoff when updating the work flake's `nixcfg` input for `mimir2` and
`loki`. The base checkout supplies the shared Bash files. NDTK is NostraDavid's
Toolkit; its source layout is described in
[the NDTK README](../dotfiles/ndtk/README.md).

## Shared Bash files

The base `portable-cli` module links `~/.bashrc`, `~/.bashrc.d/`,
`~/.bash_aliases`, and `~/.bash_profile` on both hosts. The main `.bashrc` loads
the files in `.bashrc.d` in a fixed order. Interactive shells load
`~/.bashrc.work` before `~/.bashrc.local`, then append the history hooks.
Non-interactive shells load only the environment settings.

`.bash_aliases-common` is gone. Shared aliases live in `.bash_aliases`; only
Linux system commands remain behind a platform check. The shared alias file then
sources `~/.bash_aliases.work` when it exists, so work aliases can override the
shared definitions. Shell functions live in `.bashrc.d/functions.bash`. The
alias file prints one yellow warning when an optional `lsd`, `ncdu`, or
`project_color` command is missing.

Remove work-repository mappings for the shared Bash files. Keep work-only
settings in `~/.bashrc.work`, aliases in `~/.bash_aliases.work`, and the work
Git identity in its existing work-owned file. Review work aliases and functions
before deleting them: remove only definitions now supplied by the base files.

## NDTK commands and data

Personal command sources moved from `dotfiles/local/.local/bin/` and
`dotfiles/dev/` to `dotfiles/ndtk/.local/bin/`. The curated repository list and
Azure example moved to `dotfiles/ndtk/.config/ndtk/`. The commands use these
default paths:

| Purpose                                                 | Path                       |
| ------------------------------------------------------- | -------------------------- |
| Repository list for `restore_repos`                     | `~/.config/ndtk/repos.dat` |
| Azure settings for `get_azure_repos`                    | `~/.config/ndtk/azure.env` |
| Generated list from `save_cloned_repos save SEARCH_DIR` | `SEARCH_DIR/repos.dat`     |

The old Wodan mapping put the repository scripts, `repos.dat`, and the Azure
example under `~/dev/`. It no longer does. `restore_repos` now reads the curated
list from XDG config, while `save_cloned_repos save SEARCH_DIR` writes a
separate generated list to `SEARCH_DIR/repos.dat`. Use `--output` to choose
another path, including the previous XDG state location.

The base scripts now use the rewritten work implementations. Update existing
commands to use `find-uncommitted scan PATH`, `save_cloned_repos save PATH`,
`restore_repos restore PATH`, and
`update_all_local_repos update --project PATH`. Their `unit-test`, `tests`, and
`test` commands run local tests.

The work migration removes seven duplicate scripts and points their command
links and compatibility aliases at base. Keep the importable `grab.py` and
`repo_timestamps.py` aliases in `~/.local/bin/`. Keep the provider-discovery
scripts and private repository lists in the work configuration.

Set `NDTK_BITBUCKET_HOST` and `NDTK_AZURE_USERNAME` in the work profile's
`home.sessionVariables`. The base defaults are `bitbucket.org` and `git`. An
explicit username in a remote URL takes precedence over the Azure default.

`get_azure_repos` now reads `~/.config/ndtk/azure.env` explicitly instead of
loading a `.env` file from the current directory. If the work host has Azure
settings or a generated repository list, move them to the new paths before
removing the old files. Keep `azure.env` and its token outside Git. On Wodan,
`rsync-bitvavo` now runs from `~/.local/bin/`; map it there on a work host if
needed.

The NDTK bin and config links currently live in Wodan's
[`dotfiles.nix`](../modules/home/dotfiles.nix). `portable-cli` does not import
that module. Wodan maps each regular file in `.local/bin/` to a command without
its `.py` or `.sh` suffix. The work hosts need their own Home Manager mappings
for any NDTK commands and config files they use. Keep work copies until those
mappings point at the base checkout; then remove the duplicate sources. Do not
import Wodan's full dotfiles module just to obtain NDTK.

## Apply and check

1. Commit and push the base changes, then update the work flake's `nixcfg`
   input. To test local base changes before publishing them, add
   `--override-input nixcfg path:/home/david/nixcfg --no-write-lock-file` to the
   work build and switch commands. The GitHub input requires published changes.
2. Remove conflicting work-owned Bash mappings and add any needed NDTK mappings.
   Evaluate and switch both hosts using the commands in
   [the work integration guide](work-repo-integration.md#check-and-apply-the-work-flake).
3. Check that `~/.bashrc.d/environment.bash` exists, a new interactive Bash
   loads `~/.bashrc.work`, and each chosen NDTK command resolves from
   `~/.local/bin/`.

The Bash links read the editable base checkout. On a live host, updating that
checkout changes `.bashrc` before Home Manager creates the new `.bashrc.d` link.
Use an existing shell to run the work switch promptly after updating the
checkout.
