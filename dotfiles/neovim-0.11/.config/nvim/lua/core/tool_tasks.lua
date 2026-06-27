-- Discoverable wrappers around external tools that do not need dedicated plugins.
local M = {}

local uv = vim.uv or vim.loop

local tasks = {
	{
		id = "json-format",
		label = "JSON: jq format current file",
		exe = "jq",
		ft = { "json", "jsonc" },
		command = function(ctx)
			return ("jq . %s"):format(ctx.file)
		end,
	},
	{
		id = "yaml-view",
		label = "YAML: yq view current file",
		exe = "yq",
		ft = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values" },
		command = function(ctx)
			return ("yq . %s"):format(ctx.file)
		end,
	},
	{
		id = "xml-format",
		label = "XML: xmllint format current file",
		exe = "xmllint",
		ft = { "xml", "xsl" },
		command = function(ctx)
			return ("xmllint --format %s"):format(ctx.file)
		end,
	},
	{
		id = "gzip-preview",
		label = "Compression: preview gzip with gzip -dc",
		exe = "gzip",
		ext = { "gz" },
		command = function(ctx)
			return ("gzip -dc %s | sed -n '1,200p'"):format(ctx.file)
		end,
	},
	{
		id = "zstd-preview",
		label = "Compression: preview zstd with zstdcat",
		exe = "zstdcat",
		ext = { "zst", "zstd" },
		command = function(ctx)
			return ("zstdcat %s | sed -n '1,200p'"):format(ctx.file)
		end,
	},
	{
		id = "zip-list",
		label = "Compression: list zip contents",
		exe = "unzip",
		ext = { "zip" },
		command = function(ctx)
			return ("unzip -l %s"):format(ctx.file)
		end,
	},
	{
		id = "visidata",
		label = "Data: open current file in visidata",
		exe = "visidata",
		ft = { "csv", "tsv" },
		ext = { "csv", "tsv", "parquet", "json", "jsonl" },
		interactive = true,
		command = function(ctx)
			return ("visidata %s"):format(ctx.file)
		end,
	},
	{
		id = "duckdb-parquet",
		label = "Data: DuckDB preview parquet",
		exe = "duckdb",
		ext = { "parquet" },
		command = function(ctx)
			return ("duckdb -c %s"):format(
				vim.fn.shellescape(("SELECT * FROM read_parquet(%s) LIMIT 100;"):format(ctx.file))
			)
		end,
	},
	{
		id = "duckdb-csv",
		label = "Data: DuckDB preview CSV",
		exe = "duckdb",
		ft = { "csv", "tsv" },
		ext = { "csv", "tsv" },
		command = function(ctx)
			return ("duckdb -c %s"):format(
				vim.fn.shellescape(("SELECT * FROM read_csv_auto(%s) LIMIT 100;"):format(ctx.file))
			)
		end,
	},
	{
		id = "parquet-schema",
		label = "Data: parquet-tools schema",
		exe = "parquet-tools",
		ext = { "parquet" },
		command = function(ctx)
			return ("parquet-tools schema %s"):format(ctx.file)
		end,
	},
	{
		id = "gh-pr-status",
		label = "GitHub: PR status",
		exe = "gh",
		project = true,
		command = function()
			return "gh pr status"
		end,
	},
	{
		id = "gh-run-list",
		label = "GitHub: workflow runs",
		exe = "gh",
		project = true,
		command = function()
			return "gh run list"
		end,
	},
	{
		id = "jj-status",
		label = "Jujutsu: status",
		exe = "jj",
		project = true,
		command = function()
			return "jj status"
		end,
	},
	{
		id = "jj-log",
		label = "Jujutsu: log",
		exe = "jj",
		project = true,
		command = function()
			return "jj log"
		end,
	},
	{
		id = "jj-diff",
		label = "Jujutsu: diff",
		exe = "jj",
		project = true,
		command = function()
			return "jj diff"
		end,
	},
	{
		id = "austin-current",
		label = "Python: profile current file with Austin",
		exe = "austin",
		ft = { "python" },
		command = function(ctx)
			return ("austin python %s"):format(ctx.file)
		end,
	},
	{
		id = "scalene-current",
		label = "Python: profile current file with Scalene",
		exe = "scalene",
		ft = { "python" },
		command = function(ctx)
			return ("scalene %s"):format(ctx.file)
		end,
	},
	{
		id = "ty-current",
		label = "Python: ty check current file",
		exe = "ty",
		ft = { "python" },
		command = function(ctx)
			return ("ty check %s"):format(ctx.file)
		end,
	},
	{
		id = "just-choose",
		label = "Project: choose just task",
		exe = "just",
		project = true,
		interactive = true,
		command = function()
			return "just --choose"
		end,
	},
	{
		id = "make",
		label = "Project: make",
		exe = "make",
		project = true,
		command = function()
			return "make"
		end,
	},
	{
		id = "ai-gemini",
		label = "AI: Gemini CLI",
		exe = "gemini",
		project = true,
		interactive = true,
		command = function()
			return "gemini"
		end,
	},
	{
		id = "ai-copilot",
		label = "AI: GitHub Copilot CLI",
		exe = "github-copilot-cli",
		project = true,
		interactive = true,
		command = function()
			return "github-copilot-cli"
		end,
	},
	{
		id = "ai-codex",
		label = "AI: Codex CLI",
		exe = "codex",
		project = true,
		interactive = true,
		command = function()
			return "codex"
		end,
	},
}

local by_id = {}
for _, task in ipairs(tasks) do
	by_id[task.id] = task
end

local function notify_missing(task)
	vim.notify(("Tool '%s' is not executable for %s"):format(task.exe, task.label), vim.log.levels.WARN)
end

local function file_context()
	local file = vim.fn.expand("%:p")
	local filename = vim.fn.expand("%:t")
	local ext = vim.fn.expand("%:e")

	return {
		cwd = vim.fn.getcwd(),
		file_path = file,
		file = file ~= "" and vim.fn.shellescape(file) or "",
		filename = filename,
		ext = ext,
		ft = vim.bo.filetype,
	}
end

local function includes(values, needle)
	if not values then
		return false
	end
	for _, value in ipairs(values) do
		if value == needle then
			return true
		end
	end
	return false
end

local function has_file(ctx)
	return ctx.file_path ~= "" and uv.fs_stat(ctx.file_path) ~= nil
end

local function is_relevant(task, ctx)
	if task.ft and includes(task.ft, ctx.ft) then
		return true
	end
	if task.ext and includes(task.ext, ctx.ext) then
		return true
	end
	return task.project == true
end

local function has_executable(task)
	return vim.fn.executable(task.exe) == 1
end

local function run_terminal(command, task)
	local ok, terminal = pcall(require, "toggleterm.terminal")
	if not ok then
		vim.cmd("botright split")
		vim.cmd("terminal " .. command)
		return
	end

	terminal.Terminal
		:new({
			cmd = command,
			direction = "float",
			close_on_exit = false,
			hidden = true,
			display_name = task.label,
		})
		:toggle()
end

local function run_overseer(command, task, ctx)
	local ok, overseer = pcall(require, "overseer")
	if not ok then
		vim.notify("overseer.nvim is not available", vim.log.levels.WARN)
		return
	end

	local overseer_task = overseer.new_task({
		name = task.label,
		cmd = vim.o.shell,
		args = { vim.o.shellcmdflag, command },
		cwd = ctx.cwd,
		components = { "default" },
	})
	overseer_task:start()
	overseer.open({ enter = false })
end

function M.run(id)
	local task = by_id[id]
	if not task then
		vim.notify(("Unknown Nostra tool task: %s"):format(id), vim.log.levels.WARN)
		return
	end
	if not has_executable(task) then
		notify_missing(task)
		return
	end

	local ctx = file_context()
	if (task.ft or task.ext) and not has_file(ctx) then
		vim.notify(("Task '%s' needs a saved file"):format(task.label), vim.log.levels.WARN)
		return
	end

	local command = task.command(ctx)
	if task.interactive then
		run_terminal(command, task)
	else
		run_overseer(command, task, ctx)
	end
end

function M.pick()
	local ctx = file_context()
	local available = {}
	for _, task in ipairs(tasks) do
		if is_relevant(task, ctx) and has_executable(task) then
			available[#available + 1] = task
		end
	end

	if #available == 0 then
		vim.notify("No executable Nostra tool tasks are relevant for this context", vim.log.levels.WARN)
		return
	end

	vim.ui.select(available, {
		prompt = "Nostra tools",
		format_item = function(task)
			return ("%s [%s]"):format(task.label, task.id)
		end,
	}, function(task)
		if task then
			M.run(task.id)
		end
	end)
end

function M.complete()
	local ids = {}
	for _, task in ipairs(tasks) do
		ids[#ids + 1] = task.id
	end
	return ids
end

if not vim.g.nostra_tool_tasks_registered then
	vim.g.nostra_tool_tasks_registered = true
	vim.api.nvim_create_user_command("NostraTools", function()
		M.pick()
	end, { desc = "Pick a Nostra tool task" })
	vim.api.nvim_create_user_command("NostraTool", function(opts)
		M.run(opts.args)
	end, {
		nargs = 1,
		complete = function()
			return M.complete()
		end,
		desc = "Run a Nostra tool task by id",
	})
end

return M
