-- Core: colors & theme selection
-- If vscode.nvim plugin is present it will be loaded via its config. This file
-- provides a lightweight fallback and a helper to switch styles.

local function fallback()
	local ok, _ = pcall(vim.cmd, "colorscheme habamax")
	if not ok then
		vim.notify("Fallback colorscheme unavailable", vim.log.levels.WARN)
	end
end

-- Expose helper to switch vscode style dynamically
local M = {}
function M.vscode_style(style)
	local ok, vscode = pcall(require, "vscode")
	if not ok then
		fallback()
		return
	end
	if style then
		vim.o.background = (style == 'light') and 'light' or 'dark'
	end
	local opts_ok, colors_mod = pcall(require, 'vscode.colors')
	local c = opts_ok and colors_mod.get_colors() or {}
	-- Reapply setup with current background influenced style (user overrides remain minimal here)
	vscode.setup({
		style = style or ((vim.o.background == 'light') and 'light' or 'dark'),
		transparent = false,
		italic_comments = true,
		italic_inlayhints = true,
		underline_links = true,
		disable_nvimtree_bg = true,
		terminal_colors = true,
		color_overrides = { vscLineNumber = '#FFFFFF' },
		group_overrides = opts_ok and {
			Cursor = { fg = c.vscDarkBlue, bg = c.vscLightGreen, bold = true },
		} or {},
	})
	vim.cmd.colorscheme('vscode')
end

-- If vscode not yet loaded (e.g. very early), do nothing; lazy plugin will call
-- its own setup soon. Provide fallback if user tries to change style before load.

return M
