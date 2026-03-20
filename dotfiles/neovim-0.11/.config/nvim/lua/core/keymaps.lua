-- Core: keymaps
local map = vim.keymap.set
local opts = { silent = true }

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
map("n", "<leader>q", ":quit<CR>", { desc = "Quit" })
map("n", "<leader>e", "<cmd>Neotree filesystem reveal right<CR>", { desc = "Reveal in explorer" })
map("n", "<C-b>", "<cmd>Neotree filesystem toggle right<CR>", { desc = "Toggle explorer" })
map("n", "<C-Tab>", "<cmd>bnext<CR>", { desc = "Next tab" })
map("n", "<C-S-Tab>", "<cmd>bprevious<CR>", { desc = "Previous tab" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Toggle relative number
map("n", "<leader>tn", function()
	vim.opt.relativenumber = not vim.opt.relativenumber:get()
end, { desc = "Toggle relative number" })

-- Diagnostics quick access (additional to diagnostics.lua list / float)
map("n", "<leader>d", vim.diagnostic.setloclist, { desc = "Diagnostics loclist" })

-- Window navigation
map("n", "<C-h>", "<C-w><C-h>", { desc = "Move focus left" })
map("n", "<C-l>", "<C-w><C-l>", { desc = "Move focus right" })
map("n", "<C-j>", "<C-w><C-j>", { desc = "Move focus down" })
map("n", "<C-k>", "<C-w><C-k>", { desc = "Move focus up" })

return {}
