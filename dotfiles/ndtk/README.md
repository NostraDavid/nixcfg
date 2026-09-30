# NDTK

NDTK means NostraDavid's Toolkit. It groups personal commands and their
configuration.

- `.local/bin/` contains commands linked into `~/.local/bin/` by Home Manager.
- `.config/ndtk/` contains the curated Git repository list and an Azure
  configuration example. Home Manager links both into `~/.config/ndtk/`.
- `tests/` checks the commands without contacting remote services.

`save_cloned_repos` writes generated lists to `~/.local/state/ndtk/repos.dat`.
To use `get_azure_repos`, copy `~/.config/ndtk/azure.env.example` to `azure.env`
and supply your Azure settings. Keep credentials out of Git.
