-- plugins/dev.lua - Language-specific tooling.
local lsp_keymaps = require("core.lsp_keymaps")

return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		ft = { "rust" },
		init = function()
			vim.g.rustaceanvim = {
				server = {
					on_attach = lsp_keymaps.on_attach,
					default_settings = {
						["rust-analyzer"] = {
							cargo = {
								allFeatures = true,
							},
							checkOnSave = {
								command = "clippy",
							},
							procMacro = {
								enable = true,
							},
						},
					},
				},
			}
		end,
	},
	{
		"Saecki/crates.nvim",
		version = "*",
		ft = { "toml" },
		opts = {},
	},
}
