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
			local function linter_available(name)
				local spec = lint.linters[name]
				if not spec then
					return false
				end

				local cmd = spec.cmd
				if type(cmd) ~= "string" or cmd == "" then
					return true
				end

				return vim.fn.executable(cmd) == 1
			end

			local function available_linters(names)
				local enabled = {}
				for _, name in ipairs(names) do
					if linter_available(name) then
						enabled[#enabled + 1] = name
					end
				end
				return enabled
			end

			lint.linters_by_ft = {
				bash = available_linters({ "shellcheck" }),
				dockerfile = available_linters({ "hadolint" }),
				markdown = available_linters({ "markdownlint-cli2" }),
				sh = available_linters({ "shellcheck" }),
				sql = available_linters({ "sqlfluff" }),
				zsh = available_linters({ "shellcheck" }),
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
