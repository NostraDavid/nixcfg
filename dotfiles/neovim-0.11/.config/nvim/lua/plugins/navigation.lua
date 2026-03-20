-- plugins/navigation.lua - VS Code-like navigation, search, explorer and comments
local function telescope_builtin(name, opts)
	return function()
		require("telescope.builtin")[name](opts or {})
	end
end

local function workspace_symbols()
	local builtin = require("telescope.builtin")
	if next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil then
		builtin.lsp_dynamic_workspace_symbols()
		return
	end
	local ok = pcall(builtin.treesitter, { symbols = { "class", "function", "method", "struct" } })
	if not ok then
		builtin.current_buffer_fuzzy_find()
	end
end

local function document_symbols()
	local builtin = require("telescope.builtin")
	if next(vim.lsp.get_clients({ bufnr = 0 })) ~= nil then
		builtin.lsp_document_symbols()
		return
	end
	local ok = pcall(builtin.treesitter, { symbols = { "class", "function", "method", "struct" } })
	if not ok then
		builtin.current_buffer_fuzzy_find()
	end
end

return {
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.8",
		cmd = "Telescope",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			defaults = {
				layout_strategy = "horizontal",
				layout_config = {
					prompt_position = "top",
					width = 0.95,
					height = 0.90,
					preview_width = 0.55,
				},
				sorting_strategy = "ascending",
				path_display = { "truncate" },
			},
			pickers = {
				find_files = {
					hidden = true,
					find_command = {
						"fd",
						"--type",
						"f",
						"--strip-cwd-prefix",
						"--hidden",
						"--exclude",
						".git",
					},
				},
			},
		},
		config = function(_, opts)
			require("telescope").setup(opts)
		end,
		keys = {
			{
				"<C-p>",
				telescope_builtin("find_files"),
				desc = "Find files",
			},
			{
				"<C-t>",
				workspace_symbols,
				desc = "Search workspace symbols",
			},
			{
				"<leader>ff",
				telescope_builtin("find_files"),
				desc = "Find files",
			},
			{
				"<leader>fg",
				telescope_builtin("live_grep"),
				desc = "Search text",
			},
			{
				"<leader>fs",
				workspace_symbols,
				desc = "Search workspace symbols",
			},
			{
				"<leader>fS",
				document_symbols,
				desc = "Search document symbols",
			},
		},
	},
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		lazy = false,
		cmd = "Neotree",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"echasnovski/mini.icons",
		},
		opts = {
			close_if_last_window = false,
			popup_border_style = "rounded",
			enable_git_status = true,
			enable_diagnostics = true,
			open_files_do_not_replace_types = { "terminal", "Trouble", "qf" },
			window = {
				position = "right",
				width = 36,
			},
			filesystem = {
				hijack_netrw_behavior = "open_default",
				follow_current_file = {
					enabled = true,
					leave_dirs_open = true,
				},
				use_libuv_file_watcher = true,
				filtered_items = {
					visible = true,
					hide_dotfiles = false,
					hide_gitignored = false,
				},
			},
		},
		config = function(_, opts)
			require("neo-tree").setup(opts)

			vim.api.nvim_create_autocmd("VimEnter", {
				group = vim.api.nvim_create_augroup("NeoTreeStartup", { clear = true }),
				once = true,
				callback = function()
					if next(vim.api.nvim_list_uis()) == nil then
						return
					end
					vim.cmd("Neotree filesystem show right")
					pcall(vim.cmd, "wincmd p")
				end,
			})
		end,
	},
	{
		"akinsho/bufferline.nvim",
		version = "*",
		event = "VeryLazy",
		dependencies = { "echasnovski/mini.icons" },
		opts = {
			options = {
				mode = "buffers",
				always_show_bufferline = true,
				show_close_icon = false,
				show_buffer_close_icons = false,
				separator_style = "thin",
				diagnostics = "nvim_lsp",
				offsets = {
					{
						filetype = "neo-tree",
						text = "Explorer",
						text_align = "left",
						separator = true,
					},
				},
			},
		},
		config = function(_, opts)
			require("bufferline").setup(opts)
		end,
	},
	{
		"echasnovski/mini.comment",
		version = "*",
		event = "VeryLazy",
		opts = {
			mappings = {
				comment = "",
				comment_line = "",
				comment_visual = "",
				textobject = "",
			},
		},
		config = function(_, opts)
			local comment = require("mini.comment")
			comment.setup(opts)

			local function toggle_current_line()
				local line = vim.api.nvim_win_get_cursor(0)[1]
				comment.toggle_lines(line, line)
			end

			local function toggle_visual_selection()
				local line_start = vim.fn.line("v")
				local line_end = vim.fn.line(".")
				if line_start > line_end then
					line_start, line_end = line_end, line_start
				end
				comment.toggle_lines(line_start, line_end)
			end

			local map_opts = { silent = true, desc = "Toggle comment" }
			pcall(vim.keymap.del, "n", "gc")
			pcall(vim.keymap.del, "n", "gcc")
			pcall(vim.keymap.del, "x", "gc")
			pcall(vim.keymap.del, "o", "gc")
			vim.keymap.set("n", "<C-_>", toggle_current_line, map_opts)
			vim.keymap.set("x", "<C-_>", toggle_visual_selection, map_opts)
			vim.keymap.set("n", "<C-/>", toggle_current_line, map_opts)
			vim.keymap.set("x", "<C-/>", toggle_visual_selection, map_opts)
		end,
	},
}
