-- plugins/colors.lua - Theme plugins
return {
	{
		"Mofiqul/vscode.nvim",
		version = "*",
		priority = 1000, -- load before other UI plugins for proper highlighting
		opts = function()
			-- Decide style based on current background (user may set vim.o.background earlier)
			local style = (vim.o.background == "light") and "light" or "dark"
			local c_ok, colors = pcall(require, "vscode.colors")
			local c = c_ok and colors.get_colors() or {}
			return {
				style = style, -- 'dark' | 'light' | 'dark_dimmed'
				transparent = false,
				italic_comments = true,
				italic_inlayhints = true,
				underline_links = true,
				disable_nvimtree_bg = true,
				terminal_colors = true,
				color_overrides = {
					vscLineNumber = "#FFFFFF", -- example override
				},
				group_overrides = c_ok and {
					Cursor = { fg = c.vscDarkBlue, bg = c.vscLightGreen, bold = true },
				} or {},
			}
		end,
		config = function(_, opts)
			local ok, vscode = pcall(require, "vscode")
			if not ok then
				return
			end
			vscode.setup(opts)
			-- Load theme without affecting devicons (recommended approach)
			vim.cmd.colorscheme("vscode")
		end,
	},
}
