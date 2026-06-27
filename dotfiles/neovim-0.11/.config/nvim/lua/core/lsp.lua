-- core/lsp.lua - LSP configuration layer
-- Loaded by nvim-lspconfig plugin spec via pcall(require, "core.lsp")

if not vim.lsp or not vim.lsp.config or not vim.lsp.enable then
	vim.schedule(function()
		vim.notify("vim.lsp.config/vim.lsp.enable not available (requires Neovim 0.11+)", vim.log.levels.WARN)
	end)
	return
end

if vim.g.nostra_lsp_configured then
	return {}
end
vim.g.nostra_lsp_configured = true

local lsp_keymaps = require("core.lsp_keymaps")

-- Capabilities (extend later for nvim-cmp if added)
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities.general = capabilities.general or {}
capabilities.general.positionEncodings = { "utf-16" }
capabilities.offsetEncoding = { "utf-16" }

-- Mason can have extra installed tools that we do not want treated as active LSP configs.
for _, name in ipairs({ "pyright", "sqlls", "stylua", "ty" }) do
	pcall(vim.lsp.enable, name, false)
end

local function schemastore_json()
	local ok, schemastore = pcall(require, "schemastore")
	if not ok then
		return nil
	end
	return schemastore.json.schemas()
end

local function schemastore_yaml()
	local ok, schemastore = pcall(require, "schemastore")
	if not ok then
		return nil
	end
	return schemastore.yaml.schemas()
end

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
	nixd = function()
		return {
			cmd = { "nixd" },
			root_markers = { "flake.nix", ".git" },
			settings = {
				nixd = {
					nixpkgs = {
						expr = "import (builtins.getFlake (builtins.toString ./.)).inputs.nixpkgs { }",
					},
					formatting = {
						command = { "alejandra" },
					},
					options = {
						nixos = {
							expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.wodan.options",
						},
						["home-manager"] = {
							expr = '(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.wodan.options."home-manager".users.type.getSubOptions []',
						},
					},
				},
			},
		}
	end,
	bashls = function()
		return {}
	end,
	jsonls = function()
		return {
			settings = {
				json = {
					schemas = schemastore_json(),
					validate = { enable = true },
				},
			},
		}
	end,
	yamlls = function()
		return {
			settings = {
				yaml = {
					schemaStore = { enable = false, url = "" },
					schemas = schemastore_yaml(),
					validate = true,
					hover = true,
					completion = true,
				},
			},
		}
	end,
	marksman = function()
		return {}
	end,
	basedpyright = function()
		return {}
	end,
	ruff = function()
		return {}
	end,
	cssls = function()
		return {}
	end,
	dockerls = function()
		return {}
	end,
	docker_compose_language_service = function()
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
	jinja_lsp = function()
		return {}
	end,
	zls = function()
		return {}
	end,
}

for name, cfg_fn in pairs(servers) do
	local cfg = cfg_fn() or {}
	cfg.on_attach = lsp_keymaps.on_attach
	cfg.capabilities = capabilities

	local ok_cfg, err_cfg = pcall(vim.lsp.config, name, cfg)
	if ok_cfg then
		local ok_enable, err_enable = pcall(vim.lsp.enable, name)
		if not ok_enable then
			vim.schedule(function()
				vim.notify(("LSP enable failed for %s: %s"):format(name, err_enable), vim.log.levels.WARN)
			end)
		end
	else
		vim.schedule(function()
			vim.notify(("LSP config failed for %s: %s"):format(name, err_cfg), vim.log.levels.WARN)
		end)
	end
end

-- Diagnostics configuration (non-virtual text by default; rely on signs and float)
vim.diagnostic.config({
	virtual_text = {
		spacing = 2,
		source = "if_many",
		prefix = "●",
	},
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = { border = "rounded", source = "if_many", focusable = false },
})
