-- Core: Python executable discovery for test and debug integrations.
local M = {}

function M.python_path()
	local cwd = vim.fn.getcwd()
	local candidates = {
		cwd .. "/.venv/bin/python",
		cwd .. "/venv/bin/python",
		vim.fn.exepath("python3"),
		"/usr/bin/python3",
	}

	for _, path in ipairs(candidates) do
		if path ~= nil and path ~= "" and vim.fn.executable(path) == 1 then
			return path
		end
	end

	return "python3"
end

function M.python_has_module(python, module)
	if python == nil or python == "" or vim.fn.executable(python) ~= 1 then
		return false
	end

	vim.fn.system({ python, "-c", ("import %s"):format(module) })
	return vim.v.shell_error == 0
end

function M.debugpy_python()
	local project_python = M.python_path()
	if M.python_has_module(project_python, "debugpy") then
		return project_python
	end

	local mason_python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
	if M.python_has_module(mason_python, "debugpy") then
		return mason_python
	end

	local system_python = vim.fn.exepath("python3")
	if M.python_has_module(system_python, "debugpy") then
		return system_python
	end

	return project_python
end

return M
