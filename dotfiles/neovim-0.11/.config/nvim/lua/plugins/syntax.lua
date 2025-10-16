-- plugins/syntax.lua - Syntax, Treesitter, highlighting
return {
	{ -- Tree-sitter for better syntax highlighting & parsing
		"nvim-treesitter/nvim-treesitter",
		version = "v0.10.0",
		build = ":TSUpdate",
		event = { "BufReadPre", "BufNewFile" },
		opts = {
			ensure_installed = {
				-- Core/editor
				"lua",
				"vim",
				"vimdoc",
				-- Shell / scripting
				"bash",
				-- Languages requested
				"python",
				"json",
				"yaml",
				"markdown",
				"markdown_inline",
				"dockerfile",
				"css",
				"groovy",
				"hcl",
				"html",
				"ini",
				"sql",
				"toml",
				"xml",
				-- Misc infra / queries
				"query",
				"regex",
			},
			highlight = { enable = true, additional_vim_regex_highlighting = false },
			indent = { enable = true },
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "gnn",
					node_incremental = "grn",
					scope_incremental = "grc",
					node_decremental = "grm",
				},
			},
		},
		config = function(_, opts)
			local ok, ts = pcall(require, "nvim-treesitter.configs")
			if ok then
				ts.setup(opts)
			end
		end,
	},
}
