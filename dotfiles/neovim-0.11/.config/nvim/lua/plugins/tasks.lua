-- plugins/tasks.lua - Discoverable task runners and CLI-backed VS Code alternatives.
-- Alternatives deferred for phase 1: remote-nvim/remote-sshfs/dev-container plugins,
-- CodeCompanion/Avante/CopilotChat, and browser preview plugins.
local tool_tasks = require("core.tool_tasks")

local function tool_task(id)
	return function()
		tool_tasks.run(id)
	end
end

return {
	{
		"akinsho/toggleterm.nvim",
		version = "*",
		cmd = { "ToggleTerm", "TermExec" },
		keys = {
			{ "<leader>rt", "<cmd>ToggleTerm direction=float<cr>", desc = "Terminal" },
		},
		opts = {
			direction = "float",
			close_on_exit = false,
			float_opts = {
				border = "rounded",
			},
		},
	},
	{
		"stevearc/overseer.nvim",
		cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen", "OverseerClose" },
		keys = {
			{ "<leader>rr", "<cmd>OverseerRun<cr>", desc = "Run task" },
			{ "<leader>ro", "<cmd>OverseerToggle<cr>", desc = "Task output" },
			{
				"<leader>rx",
				function()
					tool_tasks.pick()
				end,
				desc = "Nostra tools",
			},
			{ "<leader>rj", tool_task("just-choose"), desc = "Just task" },
			{ "<leader>rk", tool_task("make"), desc = "Make" },
			{ "<leader>rG", tool_task("gh-pr-status"), desc = "GitHub PR status" },
			{ "<leader>rA", tool_task("gh-run-list"), desc = "GitHub actions" },
			{ "<leader>rJ", tool_task("jj-status"), desc = "Jujutsu status" },
		},
		opts = {
			templates = { "builtin" },
			task_list = {
				direction = "bottom",
				min_height = 10,
				max_height = 20,
			},
		},
	},
	{
		"kdheepak/lazygit.nvim",
		cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
		dependencies = { "nvim-lua/plenary.nvim" },
		keys = {
			{ "<leader>rg", "<cmd>LazyGit<cr>", desc = "LazyGit" },
		},
	},
	{
		"ellisonleao/glow.nvim",
		cmd = "Glow",
		ft = { "markdown" },
		keys = {
			{ "<leader>rm", "<cmd>Glow<cr>", desc = "Markdown preview" },
		},
		opts = {
			border = "rounded",
			style = "dark",
			width = 120,
		},
	},
	{
		"hat0uma/csvview.nvim",
		ft = { "csv", "tsv" },
		cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
		keys = {
			{ "<leader>rc", "<cmd>CsvViewToggle<cr>", desc = "CSV view" },
		},
		opts = {},
	},
	{
		"andythigpen/nvim-coverage",
		cmd = {
			"Coverage",
			"CoverageClear",
			"CoverageHide",
			"CoverageLoad",
			"CoverageShow",
			"CoverageSummary",
			"CoverageToggle",
		},
		keys = {
			{ "<leader>rC", "<cmd>CoverageToggle<cr>", desc = "Coverage" },
		},
		opts = {},
	},
	{
		"nvim-pack/nvim-spectre",
		cmd = "Spectre",
		dependencies = { "nvim-lua/plenary.nvim" },
		keys = {
			{ "<leader>fR", "<cmd>Spectre<cr>", desc = "Search and replace" },
		},
	},
	{
		"sQVe/sort.nvim",
		cmd = "Sort",
		opts = {},
		keys = {
			{ "<leader>rS", "<cmd>Sort<cr>", desc = "Sort lines" },
		},
	},
	{
		"Kicamon/markdown-table-mode.nvim",
		ft = { "markdown" },
		opts = {},
	},
}
