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
inventory. `update_all_local_repos update --project SEARCH_DIR` updates existing
repositories.

The rewritten commands include local tests:

- `find-uncommitted unit-test`
- `save_cloned_repos unit-test`
- `grab tests`
- `update_all_local_repos test`

The updater reads `NDTK_BITBUCKET_HOST` for the throttled Bitbucket host,
defaulting to `bitbucket.org`. `NDTK_AZURE_USERNAME` supplies a fallback
username for PAT authentication, defaulting to `git`. Work-specific values
belong in the work profile. To use `get_azure_repos`, copy
`~/.config/ndtk/azure.env.example` to `azure.env` and supply your Azure
settings. Keep credentials out of Git.
