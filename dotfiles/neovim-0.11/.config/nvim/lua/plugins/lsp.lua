-- plugins/lsp.lua - LSP related plugins (Mason + lspconfig)
return {
	{ -- LSP server manager (Mason)
		"mason-org/mason.nvim",
		version = "v2.1.0",
		build = ":MasonUpdate",
		opts = {},
		config = function(_, opts)
			local ok, mason = pcall(require, "mason")
			if ok then
				mason.setup(opts)
			end
		end,
	},
	{ -- Mason bridge to lspconfig
		"mason-org/mason-lspconfig.nvim",
		version = "v2.1.0",
		dependencies = { "mason-org/mason.nvim" },
		opts = {
			-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
			ensure_installed = {
				"bashls", -- Shell
				"cssls", -- CSS
				"dockerls", -- Dockerfile
				"groovyls", -- Groovy
				"html", -- HTML
				"jsonls", -- JSON
				"lemminx", -- XML
				"lua_ls", -- Lua
				"marksman", -- Markdown
				"pyright", -- Python
				"sqlls", -- SQL
				"taplo", -- TOML
				"terraformls", -- HCL/Terraform
				"yamlls", -- YAML
			},
		},
		config = function(_, opts)
			local ok, mlsp = pcall(require, "mason-lspconfig")
			if ok then
				mlsp.setup(opts)
			end
		end,
	},
	{ -- Core LSP configurations
		"neovim/nvim-lspconfig",
		version = "v2.5.0",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			pcall(require, "core.lsp")
		end,
	},
}
