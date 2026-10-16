# NDTK

NDTK means NostraDavid's Toolkit. It groups personal commands and their
configuration.

- `.local/bin/` contains commands linked into `~/.local/bin/` by Home Manager.
- `.config/ndtk/` contains the curated Git repository list and an Azure
  configuration example. Home Manager links both into `~/.config/ndtk/`.
- `tests/` checks the commands without contacting remote services.

`save_cloned_repos save SEARCH_DIR` writes an inventory to
`SEARCH_DIR/repos.dat`. Use `--output` to select another destination and
`--dry-run` to print without writing. `find-uncommitted scan SEARCH_DIR` scans
repositories. `restore_repos restore TARGET_DIR` restores the configured
inventory.

`repos github clone [TARGET_DIR]` synchronizes personal and organization GitHub
repositories. `repos azure clone --root TARGET_DIR` synchronizes Azure DevOps
repositories. Both default to `~/dev`. Run `repos github --help` or
`repos azure --help` to list commands. Run `repos PROVIDER help COMMAND` or
`repos PROVIDER COMMAND --help` for command options.

`repos PROVIDER` without a command shows help and does not synchronize anything.
Every provider supports `help`, `check` for local readiness, and `test` for
network-free regression tests. Azure's `check` validates configuration and Git
availability without testing the token against Azure.

Azure Git operations, including worktree creation, allow 300 seconds each by
default. Azure API requests retain a separate 15-second timeout. Increase the
clone and fetch limits for large repositories with
`repos azure clone --clone-timeout 900 --fetch-timeout 900`. A timed-out
repository is reported as a failure while the other repositories continue. An
incomplete new clone is removed so that the next run can retry it.

Use `repos local update --project SEARCH_DIR` to update repositories already on
disk, or add `--dry-run` to preview the updates. `repos local check` verifies
the local setup.

To add a provider, add an executable `_repos_PROVIDER.py` helper with its own
dependency metadata and register the provider in `repos.sh`. Home Manager keeps
underscore-prefixed helpers importable with their file extensions. The commit
hook discovers every `_repos_*.py` helper and checks the shared commands, help
behavior, rejection of unknown commands, and provider tests. Run
`./dotfiles/ndtk/tests/test_git_repos.py` from the repository root to run the
same checks manually.

The rewritten commands include local tests:

- `find-uncommitted unit-test`
- `save_cloned_repos unit-test`
- `repos azure test`
- `repos github test`
- `repos local test`

The updater reads `NDTK_BITBUCKET_HOST` for the throttled Bitbucket host,
defaulting to `bitbucket.org`. `NDTK_AZURE_USERNAME` supplies a fallback
username for PAT authentication, defaulting to `git`. Work-specific values
belong in the work profile. To use `repos azure`, copy
`~/.config/ndtk/azure.env.example` to `azure.env` and supply your Azure
settings. Keep credentials out of Git.
