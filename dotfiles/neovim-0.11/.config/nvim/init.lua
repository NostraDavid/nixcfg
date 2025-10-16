-- Neovim 0.11 Starter Config (Modular)
-- Path managed via Home Manager (programs.nix -> .config/nvim symlink)
-- Modules live in lua/core and lua/plugins.

-- Core modules
require("core.options")
require("core.keymaps")
require("core.autocmds")
require("core.diagnostics")
require("core.statusline")
require("core.colors")

-- Plugin bootstrap placeholder (lazy.nvim etc.)
pcall(require, "plugins") -- loads lua/plugins/init.lua (returns empty table)

-- Which-key registrations (after plugins so plugin is available)
pcall(require, "core.whichkey")

-- LSP keymaps & servers (plugins set up first via lazy spec)
pcall(require, "core.lsp")

-- End of modular starter config
