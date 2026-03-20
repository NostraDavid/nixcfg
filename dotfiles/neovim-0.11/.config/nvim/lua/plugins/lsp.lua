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
				"rust_analyzer", -- Rust
				"taplo", -- TOML
				"terraformls", -- HCL/Terraform
				"yamlls", -- YAML
			},
			automatic_enable = false,
		},
		config = function(_, opts)
			local ok, mlsp = pcall(require, "mason-lspconfig")
			if ok then
				mlsp.setup(opts)
			end
		end,
	},
	{ -- Mason installer for non-LSP tools we want to keep around
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		version = "*",
		dependencies = { "mason-org/mason.nvim" },
		opts = {
			ensure_installed = {
				"actionlint",
			},
			auto_update = false,
			run_on_start = true,
			start_delay = 0,
		},
		config = function(_, opts)
			local ok, mti = pcall(require, "mason-tool-installer")
			if ok then
				mti.setup(opts)
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
