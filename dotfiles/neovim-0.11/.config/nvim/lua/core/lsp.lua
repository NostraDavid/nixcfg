-- core/lsp.lua - LSP configuration layer
-- Loaded by nvim-lspconfig plugin spec via pcall(require, 'core.lsp')

local ok_lsp, lspconfig = pcall(require, "lspconfig")
if not ok_lsp then
	return
end

-- Helper: common on_attach to set keymaps only after server attaches
local function on_attach(client, bufnr)
	local map = function(mode, lhs, rhs, desc)
		local opts = { buffer = bufnr, desc = desc }
		vim.keymap.set(mode, lhs, rhs, opts)
	end
	-- Navigation & info
	map("n", "gd", vim.lsp.buf.definition, "Goto definition")
	map("n", "gr", vim.lsp.buf.references, "References")
	map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
	map("n", "gi", vim.lsp.buf.implementation, "Goto implementation")
	map("n", "gt", vim.lsp.buf.type_definition, "Goto type")
	map("n", "K", vim.lsp.buf.hover, "Hover docs")
	map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
	map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
	map("n", "<leader>fd", function()
		vim.diagnostic.open_float(nil, { focus = false })
	end, "Line diagnostics")
	map("n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
	map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")
	map("n", "<leader>f", function()
		vim.lsp.buf.format({ async = true })
	end, "Format buffer")
end

-- Capabilities (extend later for nvim-cmp if added)
local capabilities = vim.lsp.protocol.make_client_capabilities()

-- Servers with default setup
-- https://github.com/neovim/nvim-lspconfig/blob/master/doc/configs.md
local servers = {
	lua_ls = function()
		return {
			settings = {
				Lua = {
					diagnostics = { globals = { "vim" } },
					workspace = { checkThirdParty = false },
					completion = { callSnippet = "Replace" },
				},
			},
		}
	end,
	bashls = function()
		return {}
	end,
	jsonls = function()
		return {}
	end,
	yamlls = function()
		return {}
	end,
	marksman = function()
		return {}
	end,
	pyright = function()
		return {}
	end,
	cssls = function()
		return {}
	end,
	dockerls = function()
		return {}
	end,
	groovyls = function()
		return {}
	end,
	terraformls = function()
		return {}
	end,
	html = function()
		return {}
	end,
	taplo = function()
		return {}
	end,
	sqls = function()
		return {}
	end,
	lemminx = function()
		return {}
	end,
}

for name, cfg_fn in pairs(servers) do
	local cfg = cfg_fn() or {}
	cfg.on_attach = on_attach
	cfg.capabilities = capabilities
	local ok = pcall(lspconfig[name].setup, cfg)
	if not ok then
		vim.schedule(function()
			vim.notify(("LSP setup failed for %s"):format(name), vim.log.levels.WARN)
		end)
	end
end

-- Diagnostics configuration (non-virtual text by default; rely on signs and float)
vim.diagnostic.config({
	virtual_text = false,
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = { border = "rounded", source = "if_many", focusable = false },
})
