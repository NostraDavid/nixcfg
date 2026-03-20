-- plugins/tools.lua - Formatting, linting and richer git UX
return {
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		opts = {
			notify_on_error = true,
			notify_no_formatters = false,
			formatters_by_ft = {
				bash = { "shfmt" },
				css = { "prettierd", "prettier" },
				dockerfile = { "prettierd", "prettier" },
				html = { "prettierd", "prettier" },
				json = { "prettierd", "prettier" },
				lua = { "stylua" },
				markdown = { "prettierd", "prettier" },
				nix = { "alejandra" },
				python = { "ruff_format" },
				sh = { "shfmt" },
				sql = { "sql_formatter" },
				toml = { "taplo" },
				xml = { "xmlformat" },
				yaml = { "prettierd", "prettier" },
				zsh = { "shfmt" },
			},
		},
	},
	{
		"mfussenegger/nvim-lint",
		event = { "BufReadPre", "BufNewFile" },
		config = function()
			local lint = require("lint")
			lint.linters_by_ft = {
				bash = { "shellcheck" },
				dockerfile = { "hadolint" },
				markdown = { "markdownlint-cli2" },
				sh = { "shellcheck" },
				sql = { "sqlfluff" },
				zsh = { "shellcheck" },
			}

			local group = vim.api.nvim_create_augroup("NvimLint", { clear = true })
			vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
				group = group,
				callback = function()
					lint.try_lint()
				end,
			})
		end,
	},
	{
		"sindrets/diffview.nvim",
		cmd = { "DiffviewOpen", "DiffviewFileHistory" },
		opts = {},
		keys = {
			{ "<leader>gD", "<cmd>DiffviewOpen<cr>", desc = "Diffview open" },
			{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "File history" },
		},
	},
	{
		"NeogitOrg/neogit",
		cmd = "Neogit",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"sindrets/diffview.nvim",
		},
		opts = {},
		keys = {
			{ "<leader>gg", "<cmd>Neogit<cr>", desc = "Neogit" },
		},
	},
}
