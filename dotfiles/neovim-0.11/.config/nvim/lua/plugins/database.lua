-- plugins/database.lua - Database UI and SQL helpers.
return {
	{
		"tpope/vim-dadbod",
		cmd = { "DB", "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
	},
	{
		"kristijanhusak/vim-dadbod-ui",
		cmd = { "DBUI", "DBUIToggle", "DBUIAddConnection", "DBUIFindBuffer" },
		dependencies = {
			"tpope/vim-dadbod",
			"kristijanhusak/vim-dadbod-completion",
		},
		init = function()
			vim.g.db_ui_use_nerd_fonts = 1
			vim.g.db_ui_show_database_icon = 1
			vim.g.db_ui_save_location = vim.fn.stdpath("state") .. "/dadbod-ui"
		end,
		keys = {
			{ "<leader>od", "<cmd>DBUI<cr>", desc = "Database UI" },
			{ "<leader>of", "<cmd>DBUIFindBuffer<cr>", desc = "Database buffer" },
		},
	},
}
