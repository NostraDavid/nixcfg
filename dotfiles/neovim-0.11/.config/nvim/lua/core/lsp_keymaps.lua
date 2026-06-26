-- Core: shared LSP keymaps and formatting entrypoints.
local M = {}

function M.format_buffer()
	local ok, conform = pcall(require, "conform")
	if ok then
		conform.format({ async = true, lsp_format = "fallback" })
		return
	end
	vim.lsp.buf.format({ async = true })
end

function M.on_attach(client, bufnr)
	local map = function(mode, lhs, rhs, desc)
		vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
	end

	map("n", "gd", vim.lsp.buf.definition, "Goto definition")
	map("n", "gD", vim.lsp.buf.declaration, "Goto declaration")
	map("n", "gi", vim.lsp.buf.implementation, "Goto implementation")
	map("n", "gt", vim.lsp.buf.type_definition, "Goto type")
	map("n", "K", vim.lsp.buf.hover, "Hover docs")
	map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol")
	map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
	map({ "n", "v" }, "<C-.>", vim.lsp.buf.code_action, "Code action")
	map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")
	map("n", "<leader>ld", function()
		vim.diagnostic.open_float(nil, { focus = false })
	end, "Line diagnostics")
	map("n", "<leader>lf", M.format_buffer, "Format buffer")
	map("n", "<A-F>", M.format_buffer, "Format buffer")
	map("n", "[d", vim.diagnostic.goto_prev, "Prev diagnostic")
	map("n", "]d", vim.diagnostic.goto_next, "Next diagnostic")

	if client and client.server_capabilities and client.server_capabilities.inlayHintProvider and vim.lsp.inlay_hint then
		map("n", "<leader>th", function()
			local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr })
			vim.lsp.inlay_hint.enable(not enabled, { bufnr = bufnr })
		end, "Toggle inlay hints")
	end
end

return M
