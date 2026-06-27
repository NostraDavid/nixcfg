-- plugins/ux.lua - Completion, UI polish, navigation helpers and notes
return {
	{
		"saghen/blink.cmp",
		version = "1.*",
		event = { "InsertEnter", "CmdlineEnter" },
		dependencies = { "rafamadriz/friendly-snippets" },
		opts = {
			keymap = {
				preset = "default",
				["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
				["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
				["<CR>"] = { "accept", "fallback" },
			},
			appearance = {
				nerd_font_variant = "normal",
			},
			completion = {
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
				},
			},
			signature = { enabled = true },
			sources = {
				default = { "lsp", "path", "snippets", "buffer" },
			},
			fuzzy = {
				implementation = "prefer_rust_with_warning",
			},
		},
	},
	{
		"rcarriga/nvim-notify",
		event = "VeryLazy",
		opts = {
			fps = 60,
			render = "default",
			stages = "fade_in_slide_out",
			timeout = 2500,
			background_colour = "#000000",
		},
		config = function(_, opts)
			local notify = require("notify")
			notify.setup(opts)
			vim.notify = notify
		end,
	},
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify",
		},
		opts = {
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
				},
			},
			presets = {
				bottom_search = true,
				command_palette = true,
				long_message_to_split = true,
				lsp_doc_border = true,
			},
		},
		keys = {
			{
				"<leader>sn",
				function()
					require("noice").cmd("history")
				end,
				desc = "Notification history",
			},
		},
	},
	{
		"folke/snacks.nvim",
		priority = 900,
		lazy = false,
		opts = {
			bigfile = { enabled = true },
			indent = { enabled = true },
			input = { enabled = true },
			quickfile = { enabled = true },
			words = { enabled = true },
		},
	},
	{
		"rachartier/tiny-inline-diagnostic.nvim",
		event = "LspAttach",
		priority = 1000,
		opts = {},
		config = function(_, opts)
			require("tiny-inline-diagnostic").setup(opts)
			vim.diagnostic.config({ virtual_text = false })
		end,
	},
	{
		"folke/flash.nvim",
		event = "VeryLazy",
		opts = {},
		keys = {
			{
				"<leader>j",
				function()
					require("flash").jump()
				end,
				desc = "Jump",
			},
			{
				"<leader>J",
				function()
					require("flash").treesitter()
				end,
				desc = "Treesitter jump",
			},
		},
	},
	{
		"monaqa/dial.nvim",
		keys = {
			{
				"<C-a>",
				function()
					require("dial.map").manipulate("increment", "normal")
				end,
				desc = "Increment",
			},
			{
				"<C-x>",
				function()
					require("dial.map").manipulate("decrement", "normal")
				end,
				desc = "Decrement",
			},
			{
				"g<C-a>",
				function()
					require("dial.map").manipulate("increment", "gnormal")
				end,
				desc = "Increment sequence",
			},
			{
				"g<C-x>",
				function()
					require("dial.map").manipulate("decrement", "gnormal")
				end,
				desc = "Decrement sequence",
			},
			{
				"<C-a>",
				function()
					require("dial.map").manipulate("increment", "visual")
				end,
				mode = "v",
				desc = "Increment",
			},
			{
				"<C-x>",
				function()
					require("dial.map").manipulate("decrement", "visual")
				end,
				mode = "v",
				desc = "Decrement",
			},
		},
	},
	{
		"gbprod/substitute.nvim",
		keys = {
			{
				"<leader>rsub",
				function()
					require("substitute").operator()
				end,
				desc = "Substitute operator",
			},
			{
				"<leader>rsu",
				function()
					require("substitute").line()
				end,
				desc = "Substitute line",
			},
			{
				"<leader>rsu",
				function()
					require("substitute").visual()
				end,
				mode = "x",
				desc = "Substitute selection",
			},
		},
		opts = {},
	},
	{
		"abecodes/tabout.nvim",
		event = "InsertEnter",
		opts = {
			tabout = {
				enable = true,
			},
			tabkey = "<A-l>",
			backwards_tabkey = "<A-h>",
			act_as_tab = true,
			act_as_shift_tab = false,
			enable_backwards = true,
		},
	},
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		opts = {},
		keys = {
			{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Diagnostics (Trouble)" },
			{ "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer diagnostics (Trouble)" },
			{ "<leader>xl", "<cmd>Trouble loclist toggle<cr>", desc = "Location list (Trouble)" },
			{ "<leader>xq", "<cmd>Trouble qflist toggle<cr>", desc = "Quickfix (Trouble)" },
			{ "grr", "<cmd>Trouble lsp_references toggle<cr>", desc = "References (Trouble)" },
		},
	},
	{
		"folke/todo-comments.nvim",
		event = { "BufReadPost", "BufNewFile" },
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			signs = false,
		},
		keys = {
			{
				"]t",
				function()
					require("todo-comments").jump_next()
				end,
				desc = "Next todo comment",
			},
			{
				"[t",
				function()
					require("todo-comments").jump_prev()
				end,
				desc = "Previous todo comment",
			},
			{ "<leader>st", "<cmd>TodoTelescope<cr>", desc = "Todo comments" },
			{ "<leader>xt", "<cmd>Trouble todo toggle<cr>", desc = "Todo comments (Trouble)" },
		},
	},
	{
		-- Alternatives deferred: markdown-preview.nvim, peek.nvim, and
		-- live-preview.nvim. Phase 1 keeps preview terminal-only via glow.nvim.
		"MeanderingProgrammer/render-markdown.nvim",
		ft = { "markdown", "quarto" },
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"echasnovski/mini.icons",
		},
		opts = {},
	},
}
