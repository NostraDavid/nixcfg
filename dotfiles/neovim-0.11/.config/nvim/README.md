# Neovim Profile

This profile targets Neovim 0.11+ APIs and is currently used with Neovim
0.12.x. The directory name is kept as `neovim-0.11` because Home Manager already
links it from `modules/dotfiles.nix`; rename it in a separate cleanup if the
dotfiles versioning convention should match the installed binary exactly.

## Structure

- `init.lua` loads core modules first, then `lazy.nvim` plugin specs.
- `lua/core/` contains editor behavior that should work without plugin state.
- `lua/plugins/` contains grouped lazy.nvim specs.
- `lazy-lock.json` is the committed plugin lockfile and must be updated only
  after reviewing plugin changes.

## Plugin Policy

This profile is intentionally lazy.nvim and Mason first. Nix still provides the
base editor and common CLI tools, but plugin and Mason tool updates happen at
runtime and are pinned by `lazy-lock.json`.

Rules for adding plugins:

- Check https://dotfyle.com/neovim/plugins and the upstream repository before
  adding a plugin.
- Prefer maintained plugins with recent releases, clear licenses, and small
  dependency surfaces.
- Add new plugins to the closest existing `lua/plugins/*.lua` group.
- Commit `lazy-lock.json` with plugin changes.
- Do not store tokens, database URLs, passwords, or host-specific secrets in
  plugin config.

Mason-managed tools must stay listed explicitly in `lua/plugins/lsp.lua` or the
debug/test module that uses them. If a tool becomes critical for daily startup,
prefer installing it through Nix as well.

## VS Code Compatibility

VS Code muscle memory is treated as a first-class migration layer:

- `Ctrl-p`: find files.
- `Ctrl-Shift-p`: command palette.
- `Ctrl-Shift-f`: workspace text search.
- `Ctrl-Shift-o`: document symbols.
- `Ctrl-b`: toggle explorer.
- `Ctrl-s`: save.
- `Ctrl-\``: toggle terminal split.
- `Ctrl-Tab` / `Ctrl-Shift-Tab`: next/previous buffer.
- `F2`: rename symbol.
- `Ctrl-.`: code action.
- `Alt-Shift-f`: format buffer when the terminal sends it as `<A-F>`.
- `Alt-Up` / `Alt-Down`: move line or selection.
- `Ctrl-/`: toggle comments when the terminal sends it as `<C-/>` or `<C-_>`.

Terminal emulators vary in which modified keys they send to Neovim. If a VS
Code-style key does not fire, inspect it with `:h key-notation` and `Ctrl-v`
inside insert mode.

## Lua Tooling

- `stylua` is the formatter. It matches the existing Neovim Lua shape: tabs,
  double quotes when practical, and 120-column lines.
- `selene` is the linter/static analyzer. It is fast enough for editor feedback
  and understands the custom `vim` global through the repo `vim.yml`.
- `lua-language-server` is the type/IDE layer. `lazydev.nvim` adds Neovim plugin
  and runtime library context so LuaLS behaves more like VS Code extension
  support for this config.

## Safety

- `lazy.nvim` bootstrap checks `git` exit codes and reports clone/fetch/checkout
  failures instead of silently continuing.
- Dadbod UI state is written under Neovim state, not inside the repo.
- Database credentials should come from environment variables, password manager
  commands, or project-local ignored files.
- The config exposes `:NvimConfigHealth`, backed by `:checkhealth nvim_config`,
  for checking required binaries and Mason-managed tools.

## Validation

Use temporary XDG directories for smoke tests so Neovim can write logs, ShaDa,
plugin data, and Mason state without touching the real home directory:

```bash
tmp=$(mktemp -d)
XDG_CONFIG_HOME=$PWD/dotfiles/neovim-0.11/.config \
XDG_DATA_HOME=$tmp/data \
XDG_STATE_HOME=$tmp/state \
XDG_CACHE_HOME=$tmp/cache \
nvim --headless '+checkhealth nvim_config' '+quitall'
```

For a full interactive check, open Neovim normally and verify explorer, search,
tabs, formatting, diagnostics, rename, code actions, debug, tests, and Git hunk
actions.
