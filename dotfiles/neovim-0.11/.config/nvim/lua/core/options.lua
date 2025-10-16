-- Core: options

-- UI
vim.o.number = true
vim.o.relativenumber = true
vim.o.termguicolors = true
vim.o.signcolumn = "yes"
vim.o.cursorline = true
vim.o.showmode = false -- Mode shown in statusline plugin instead

-- Indentation
vim.o.shiftwidth = 2
vim.o.tabstop = 2
vim.o.expandtab = true
vim.o.smartindent = true
vim.o.breakindent = true -- Preserve visual indent when wrapping

-- Splits
vim.o.splitright = true
vim.o.splitbelow = true

-- Scrolling
vim.o.scrolloff = 10 -- Keep more context around cursor
vim.o.sidescrolloff = 8

-- Performance
vim.o.updatetime = 250 -- Faster CursorHold / diagnostics
vim.o.timeoutlen = 300 -- Quicker mapped sequence timeout

-- Misc
vim.o.wrap = false
-- Use system clipboard for all yank/paste operations (scheduled to reduce startup cost)
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)
vim.o.undofile = true -- Persistent undo
vim.o.ignorecase = true -- Case-insensitive by default
vim.o.smartcase = true -- Become case-sensitive if capital in search
vim.o.list = true -- Show invisible characters
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.o.inccommand = "split" -- Live preview of :substitute
vim.o.confirm = true -- Prompt to save before commands that would fail

-- Statusline (global)
vim.o.laststatus = 3

return {}
