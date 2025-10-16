-- Pin lazy.nvim to a specific tag for reproducibility.
-- Update TAG when you intentionally upgrade; check releases:
-- https://github.com/folke/lazy.nvim/releases
local LAZY_TAG = "v11.17.1"
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
	vim.fn.system({ "git", "-C", lazypath, "checkout", LAZY_TAG })
else
	local current = vim.fn.system({ "git", "-C", lazypath, "describe", "--tags", "--exact-match" })
	if not current:match(LAZY_TAG) then
		vim.fn.system({ "git", "-C", lazypath, "fetch", "--tags", "--force" })
		vim.fn.system({ "git", "-C", lazypath, "checkout", LAZY_TAG })
	end
end
vim.opt.rtp:prepend(lazypath)

-- Collect plugin specs from grouped modules
local groups = {
	require("plugins.ui"),
	require("plugins.git"),
	require("plugins.syntax"),
	require("plugins.lsp"),
	require("plugins.colors"),
}
local specs = {}
for _, group in ipairs(groups) do
	for _, spec in ipairs(group) do
		specs[#specs + 1] = spec
	end
end

require("lazy").setup(specs)

return {}
