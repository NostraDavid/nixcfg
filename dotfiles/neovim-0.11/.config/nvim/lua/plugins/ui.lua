-- plugins/ui.lua - UI related plugins (which-key, icons)
return {
	{ -- Keybinding popup
		"folke/which-key.nvim",
		version = "*",
		event = "VimEnter",
		opts = { delay = 0 },
		config = function(_, opts)
			local wk = require("which-key")
			wk.setup(opts)
			pcall(require, "core.whichkey")
		end,
	},
	{ -- Icons (mock devicons via mini.icons)
		"echasnovski/mini.icons",
		version = "*",
		opts = {},
		lazy = true,
		specs = { { "nvim-tree/nvim-web-devicons", enabled = false, optional = true } },
		init = function()
			package.preload["nvim-web-devicons"] = function()
				require("mini.icons").mock_nvim_web_devicons()
				return package.loaded["nvim-web-devicons"]
			end
		end,
	},
}
