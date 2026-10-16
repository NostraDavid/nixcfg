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

`repos github [TARGET_DIR]` synchronizes personal and organization GitHub
repositories. `repos azure --root TARGET_DIR` synchronizes Azure DevOps
repositories. Both default to `~/dev`. Run `repos github --help` or
`repos azure --help` for their existing provider-specific options.

Use `repos local update --project SEARCH_DIR` to update repositories already on
disk, or add `--dry-run` to preview the updates. `repos local check` verifies
the local setup.

To add a provider, add an executable `_repos_PROVIDER.py` helper with its own
dependency metadata and register the provider in `repos.sh`. Home Manager keeps
underscore-prefixed helpers importable with their file extensions.

The rewritten commands include local tests:

- `find-uncommitted unit-test`
- `save_cloned_repos unit-test`
- `repos github tests`
- `repos local test`

The updater reads `NDTK_BITBUCKET_HOST` for the throttled Bitbucket host,
defaulting to `bitbucket.org`. `NDTK_AZURE_USERNAME` supplies a fallback
username for PAT authentication, defaulting to `git`. Work-specific values
belong in the work profile. To use `repos azure`, copy
`~/.config/ndtk/azure.env.example` to `azure.env` and supply your Azure
settings. Keep credentials out of Git.
