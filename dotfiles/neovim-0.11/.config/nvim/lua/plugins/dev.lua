-- plugins/dev.lua - Language-specific tooling, tests, database UI and debugging
local function lsp_on_attach(client, bufnr)
	local map = function(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
	end

	map("n", "gd", vim.lsp.buf.definition, "Goto definition")
	map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
	map("n", "gi", vim.lsp.buf.implementation, "Goto implementation")
	map("n", "gt", vim.lsp.buf.type_definition, "Goto type")
	map("n", "K", vim.lsp.buf.hover, "Hover docs")
	map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
	map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
	map("n", "<leader>ld", function()
		vim.diagnostic.open_float(nil, { focus = false })
	end, "Line diagnostics")
	map("n", "<leader>lf", function()
		local ok, conform = pcall(require, "conform")
		if ok then
			conform.format({ async = true, lsp_format = "fallback" })
			return
		end
		vim.lsp.buf.format({ async = true })
	end, "Format buffer")
	map("n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
	map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
end

local function python_path()
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

local function python_has_module(python, module)
	if python == nil or python == "" or vim.fn.executable(python) ~= 1 then
		return false
	end

	vim.fn.system({ python, "-c", ("import %s"):format(module) })
	return vim.v.shell_error == 0
end

local function debugpy_python()
	local project_python = python_path()
	if python_has_module(project_python, "debugpy") then
		return project_python
	end

	local mason_python = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
	if python_has_module(mason_python, "debugpy") then
		return mason_python
	end

	local system_python = vim.fn.exepath("python3")
	if python_has_module(system_python, "debugpy") then
		return system_python
	end

	return project_python
end

return {
	{
		"mrcjkb/rustaceanvim",
		version = "^6",
		ft = { "rust" },
		init = function()
			vim.g.rustaceanvim = {
				server = {
					on_attach = lsp_on_attach,
					default_settings = {
						["rust-analyzer"] = {
							cargo = {
								allFeatures = true,
							},
							checkOnSave = {
								command = "clippy",
							},
							procMacro = {
								enable = true,
							},
						},
					},
				},
			}
		end,
	},
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
		end,
		keys = {
			{ "<leader>od", "<cmd>DBUI<cr>", desc = "Database UI" },
			{ "<leader>of", "<cmd>DBUIFindBuffer<cr>", desc = "Database buffer" },
		},
	},
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"jay-babu/mason-nvim-dap.nvim",
			"mfussenegger/nvim-dap-python",
			"rcarriga/nvim-dap-ui",
			"theHamsta/nvim-dap-virtual-text",
			"nvim-neotest/nvim-nio",
		},
		keys = {
			{
				"<leader>dc",
				function()
					require("dap").continue()
				end,
				desc = "Continue",
			},
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle breakpoint",
			},
			{
				"<leader>dB",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
				end,
				desc = "Conditional breakpoint",
			},
			{
				"<leader>di",
				function()
					require("dap").step_into()
				end,
				desc = "Step into",
			},
			{
				"<leader>do",
				function()
					require("dap").step_over()
				end,
				desc = "Step over",
			},
			{
				"<leader>dO",
				function()
					require("dap").step_out()
				end,
				desc = "Step out",
			},
			{
				"<leader>dr",
				function()
					require("dap").repl.toggle()
				end,
				desc = "REPL",
			},
			{
				"<leader>du",
				function()
					require("dapui").toggle()
				end,
				desc = "Debug UI",
			},
		},
		config = function()
			local dap = require("dap")
			local dapui = require("dapui")

			require("mason-nvim-dap").setup({
				ensure_installed = { "codelldb", "python" },
				automatic_installation = false,
				handlers = {},
			})
			dapui.setup()
			require("nvim-dap-virtual-text").setup()
			require("dap-python").setup(debugpy_python())

			dap.listeners.before.attach.dapui_config = function()
				dapui.open()
			end
			dap.listeners.before.launch.dapui_config = function()
				dapui.open()
			end
			dap.listeners.before.event_terminated.dapui_config = function()
				dapui.close()
			end
			dap.listeners.before.event_exited.dapui_config = function()
				dapui.close()
			end

			dap.configurations.rust = {
				{
					name = "Launch executable",
					type = "codelldb",
					request = "launch",
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
					end,
				},
			}
			dap.configurations.c = {
				{
					name = "Launch executable",
					type = "codelldb",
					request = "launch",
					cwd = "${workspaceFolder}",
					stopOnEntry = false,
					program = function()
						return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
					end,
				},
			}
			dap.configurations.cpp = dap.configurations.c
		end,
	},
	{
		"nvim-neotest/neotest",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-neotest/nvim-nio",
			"nvim-neotest/neotest-plenary",
			"nvim-neotest/neotest-python",
			"rouge8/neotest-rust",
			"mfussenegger/nvim-dap",
		},
		keys = {
			{
				"<leader>tt",
				function()
					require("neotest").run.run()
				end,
				desc = "Nearest test",
			},
			{
				"<leader>tf",
				function()
					require("neotest").run.run(vim.fn.expand("%"))
				end,
				desc = "File tests",
			},
			{
				"<leader>td",
				function()
					require("neotest").run.run({ strategy = "dap" })
				end,
				desc = "Debug nearest test",
			},
			{
				"<leader>ts",
				function()
					require("neotest").summary.toggle()
				end,
				desc = "Test summary",
			},
			{
				"<leader>to",
				function()
					require("neotest").output.open({ enter = true, auto_close = true })
				end,
				desc = "Test output",
			},
			{
				"<leader>tO",
				function()
					require("neotest").output_panel.toggle()
				end,
				desc = "Output panel",
			},
			{
				"<leader>tS",
				function()
					require("neotest").run.stop()
				end,
				desc = "Stop tests",
			},
		},
		config = function()
			require("neotest").setup({
				adapters = {
					require("neotest-python")({
						runner = "pytest",
						python = python_path,
					}),
					require("neotest-plenary"),
					require("neotest-rust")({
						args = { "--no-capture" },
					}),
				},
				quickfix = {
					enabled = false,
				},
			})
		end,
	},
}
