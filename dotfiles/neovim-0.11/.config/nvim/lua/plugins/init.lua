-- Pin lazy.nvim to a specific tag for reproducibility.
-- Update TAG when you intentionally upgrade; check releases:
-- https://github.com/folke/lazy.nvim/releases
local LAZY_TAG = "v11.17.1"
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local uv = vim.uv or vim.loop

local function notify(msg, level)
	vim.schedule(function()
		vim.notify(msg, level or vim.log.levels.ERROR)
	end)
end

local function run(args)
	local output = vim.fn.system(args)
	return vim.v.shell_error, vim.trim(output)
end

local function fail(step, code, output)
	notify(("lazy.nvim bootstrap failed during %s (exit %d): %s"):format(step, code, output), vim.log.levels.ERROR)
	return false
end

local function ensure_lazy()
	if vim.fn.executable("git") ~= 1 then
		notify("lazy.nvim bootstrap requires git on PATH", vim.log.levels.ERROR)
		return false
	end

	if not uv.fs_stat(lazypath) then
		local code, output = run({
			"git",
			"clone",
			"--filter=blob:none",
			"--branch",
			LAZY_TAG,
			"https://github.com/folke/lazy.nvim.git",
			lazypath,
		})
		if code ~= 0 then
			return fail("clone", code, output)
		end
		return true
	end

	local code, current = run({ "git", "-C", lazypath, "describe", "--tags", "--exact-match" })
	if code == 0 and current == LAZY_TAG then
		return true
	end

	code, current = run({ "git", "-C", lazypath, "fetch", "--tags", "--force" })
	if code ~= 0 then
		return fail("fetch tags", code, current)
	end

	code, current = run({ "git", "-C", lazypath, "checkout", LAZY_TAG })
	if code ~= 0 then
		return fail("checkout " .. LAZY_TAG, code, current)
	end

	return true
end

if not ensure_lazy() then
	return {}
end

vim.opt.rtp:prepend(lazypath)

-- Collect plugin specs from grouped modules
local group_modules = {
	"plugins.ui",
	"plugins.navigation",
	"plugins.ux",
	"plugins.git",
	"plugins.tools",
	"plugins.tasks",
	"plugins.dev",
	"plugins.database",
	"plugins.debug",
	"plugins.test",
	"plugins.syntax",
	"plugins.lsp",
	"plugins.colors",
}
local specs = {}
for _, module in ipairs(group_modules) do
	local ok, group = pcall(require, module)
	if not ok then
		notify(("Failed to load %s: %s"):format(module, group), vim.log.levels.ERROR)
	elseif type(group) ~= "table" then
		notify(("Plugin module %s did not return a table"):format(module), vim.log.levels.ERROR)
	else
		for _, spec in ipairs(group) do
			specs[#specs + 1] = spec
		end
	end
end

local ok, lazy = pcall(require, "lazy")
if not ok then
	notify(("Failed to require lazy.nvim from %s: %s"):format(lazypath, lazy), vim.log.levels.ERROR)
	return {}
end

lazy.setup(specs, {
	rocks = {
		enabled = false,
	},
	checker = {
		enabled = false,
	},
})

return {}
