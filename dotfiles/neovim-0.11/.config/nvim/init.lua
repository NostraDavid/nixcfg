-- Neovim 0.11+ Starter Config (Modular)
-- Path managed via Home Manager (programs.nix -> .config/nvim symlink)
-- Modules live in lua/core and lua/plugins.

local function load_module(name, opts)
	opts = opts or {}
	local ok, err = pcall(require, name)
	if ok then
		return true
	end

	local level = opts.optional and vim.log.levels.WARN or vim.log.levels.ERROR
	local msg = ("Failed to load %s: %s"):format(name, err)
	vim.schedule(function()
		vim.notify(msg, level)
	end)
	return false
end

-- Let Neo-tree own directory browsing instead of netrw.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Core modules
load_module("core.options")
load_module("core.whitespace")
load_module("core.filetypes")
load_module("core.keymaps")
load_module("core.autocmds")
load_module("core.diagnostics")
load_module("core.statusline")
load_module("core.colors")
load_module("core.health")

-- Plugin bootstrap placeholder (lazy.nvim etc.)
load_module("plugins", { optional = true }) -- loads lua/plugins/init.lua

-- Which-key registrations (after plugins so plugin is available)
load_module("core.whichkey", { optional = true })

-- LSP servers are configured by lua/plugins/lsp.lua when nvim-lspconfig loads.

-- End of modular starter config
