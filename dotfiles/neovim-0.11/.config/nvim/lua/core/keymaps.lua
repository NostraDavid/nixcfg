-- Core: keymaps
local map = vim.keymap.set
local vscode = require("core.vscode")
local lsp_keymaps = require("core.lsp_keymaps")

-- Leader keys (globals)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Remove Neovim 0.11 default comment mappings; we use VS Code-like Ctrl-/ instead.
pcall(vim.keymap.del, "n", "gc")
pcall(vim.keymap.del, "n", "gcc")
pcall(vim.keymap.del, "x", "gc")
pcall(vim.keymap.del, "o", "gc")

-- Flag indicating if a Nerd Font is available (can be used by other plugins/config)
vim.g.have_nerd_font = true

-- Basic file/window actions
map("n", "<leader>w", ":write<CR>", { desc = "Write file" })
map({ "n", "i", "x" }, "<C-s>", "<cmd>silent write<CR>", { desc = "Save file", silent = true })
map("n", "<leader>q", ":quit<CR>", { desc = "Quit" })
map("n", "<leader>Q", ":qa<CR>", { desc = "Quit all" })
map("n", "<leader>e", "<cmd>Neotree filesystem reveal right<CR>", { desc = "Reveal in explorer" })
map("n", "<C-b>", "<cmd>Neotree filesystem toggle right<CR>", { desc = "Toggle explorer" })
map("n", "<C-`>", vscode.toggle_terminal, { desc = "Toggle terminal", silent = true })
map("t", "<C-`>", [[<C-\><C-n><cmd>lua require("core.vscode").toggle_terminal()<CR>]], { desc = "Toggle terminal", silent = true })
map("n", "<C-Tab>", "<cmd>bnext<CR>", { desc = "Next tab" })
map("n", "<C-S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous tab" })
map("n", "<A-]>", "<cmd>bnext<CR>", { desc = "Next tab" })
map("n", "<A-[>", "<cmd>bprevious<CR>", { desc = "Previous tab" })
map("n", "<leader><tab>", "<cmd>bnext<CR>", { desc = "Next tab" })
map("n", "<leader><s-tab>", "<cmd>bprevious<CR>", { desc = "Previous tab" })
map("n", "<F2>", vim.lsp.buf.rename, { desc = "Rename symbol" })
map({ "n", "x" }, "<C-.>", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<A-F>", lsp_keymaps.format_buffer, { desc = "Format buffer" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Toggle relative number
map("n", "<leader>tn", function()
	vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, { desc = "Toggle relative number" })

-- VS Code-style line movement and scrolling.
map("n", "<A-Down>", vscode.move_line_down, { desc = "Move line down", silent = true })
map("n", "<A-Up>", vscode.move_line_up, { desc = "Move line up", silent = true })
map("n", "<A-j>", vscode.move_line_down, { desc = "Move line down", silent = true })
map("n", "<A-k>", vscode.move_line_up, { desc = "Move line up", silent = true })
map("x", "<A-Down>", vscode.move_selection_down, { desc = "Move selection down", silent = true })
map("x", "<A-Up>", vscode.move_selection_up, { desc = "Move selection up", silent = true })
map("x", "<A-j>", vscode.move_selection_down, { desc = "Move selection down", silent = true })
map("x", "<A-k>", vscode.move_selection_up, { desc = "Move selection up", silent = true })
map({ "n", "x" }, "<C-Down>", "10j", { desc = "Scroll cursor down", silent = true })
map({ "n", "x" }, "<C-Up>", "10k", { desc = "Scroll cursor up", silent = true })

-- Diagnostics quick access (additional to diagnostics.lua list / float)
map("n", "<leader>lq", vim.diagnostic.setloclist, { desc = "Diagnostics loclist" })

-- Window navigation
map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus left" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus right" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus down" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus up" })

return {}
