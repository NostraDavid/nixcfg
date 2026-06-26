-- Core: health checks for this Neovim profile.
local M = {}

local uv = vim.uv or vim.loop

local groups = {
	{
		name = "Required editor tools",
		required = true,
		tools = {
			{ cmd = "git", purpose = "lazy.nvim bootstrap and plugin updates" },
			{ cmd = "rg", purpose = "Telescope live_grep" },
			{ cmd = "fd", purpose = "Telescope find_files" },
		},
	},
	{
		name = "Formatters and linters",
		required = false,
		tools = {
			{ cmd = "alejandra", purpose = "Nix formatting" },
			{ cmd = "ruff", purpose = "Python formatting and linting" },
			{ cmd = "shfmt", purpose = "Shell formatting" },
			{ cmd = "shellcheck", purpose = "Shell linting" },
			{ cmd = "sqlfluff", purpose = "SQL linting" },
			{ one_of = { "prettierd", "prettier" }, purpose = "Web, JSON, Markdown, and YAML formatting" },
			{ cmd = "selene", purpose = "Lua linting and static analysis" },
			{ cmd = "stylua", purpose = "Lua formatting" },
			{ cmd = "xmlformat", purpose = "XML formatting" },
		},
	},
	{
		name = "Language servers and debug adapters",
		required = false,
		tools = {
			{ cmd = "nixd", purpose = "Nix LSP" },
			{ cmd = "lua-language-server", purpose = "Lua LSP" },
			{ cmd = "pyright-langserver", purpose = "Python LSP" },
			{ cmd = "rust-analyzer", purpose = "Rust LSP" },
			{ cmd = "bash-language-server", purpose = "Shell LSP" },
			{ cmd = "yaml-language-server", purpose = "YAML LSP" },
			{ cmd = "vscode-json-language-server", purpose = "JSON LSP" },
			{ cmd = "taplo", purpose = "TOML LSP and formatter" },
			{ cmd = "terraform-ls", purpose = "Terraform LSP" },
			{ cmd = "codelldb", purpose = "Rust/C/C++ debugging" },
		},
	},
}

local function mason_bin(cmd)
	return vim.fn.stdpath("data") .. "/mason/bin/" .. cmd
end

local function executable(cmd)
	if vim.fn.executable(cmd) == 1 then
		return true, vim.fn.exepath(cmd)
	end

	local path = mason_bin(cmd)
	if uv.fs_stat(path) then
		return true, path
	end

	return false, nil
end

local function check_tool(tool)
	if tool.one_of then
		local checked = {}
		for _, cmd in ipairs(tool.one_of) do
			local ok, path = executable(cmd)
			if ok then
				return true, ("%s at %s"):format(cmd, path)
			end
			checked[#checked + 1] = cmd
		end
		return false, table.concat(checked, " or ")
	end

	local ok, path = executable(tool.cmd)
	return ok, ok and path or tool.cmd
end

local function health_api()
	local health = vim.health
	return {
		start = health.start or health.report_start,
		ok = health.ok or health.report_ok,
		warn = health.warn or health.report_warn,
		info = health.info or health.report_info,
		error = health.error or health.report_error,
	}
end

function M.check()
	local h = health_api()
	h.start("Nostra Neovim profile")
	h.info(("Neovim %d.%d.%d; config targets Neovim 0.11+ APIs"):format(
		vim.version().major,
		vim.version().minor,
		vim.version().patch
	))
	h.info("Plugin policy: lazy.nvim and Mason are primary; lazy-lock.json must be committed after plugin updates")

	for _, group in ipairs(groups) do
		h.start(group.name)
		for _, tool in ipairs(group.tools) do
			local ok, detail = check_tool(tool)
			local label = tool.cmd or table.concat(tool.one_of, " or ")
			local msg = ("%s - %s"):format(label, tool.purpose)
			if ok then
				h.ok(("%s (%s)"):format(msg, detail))
			elseif group.required then
				h.warn(("%s is missing"):format(msg))
			else
				h.info(("%s is not currently available; install via Mason, project devshell, or Nix when needed"):format(msg))
			end
		end
	end
end

if not vim.g.nostra_health_command_registered then
	vim.g.nostra_health_command_registered = true
	vim.api.nvim_create_user_command("NvimConfigHealth", function()
		vim.cmd("checkhealth nvim_config")
	end, { desc = "Run health checks for this Neovim profile" })
end

return M
