-- Core: autocmds
-- Auto-reload files changed outside of Neovim (Lua version of classic vimscript snippet)
vim.o.autoread = true
local autoreadGrp = vim.api.nvim_create_augroup("AutoRead", {
    clear = true
})
vim.api.nvim_create_autocmd({"FocusGained", "BufEnter", "CursorHold", "CursorHoldI"}, {
    group = autoreadGrp,
    pattern = "*",
    callback = function()
        -- Skip while in command-line mode
        if vim.fn.mode() == "c" then
            return
        end
        -- Run checktime (will prompt only if buffer modified & file changed)
        vim.cmd("checktime")
    end
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
    group = autoreadGrp,
    pattern = "*",
    callback = function()
        vim.api.nvim_echo({{"File changed on disk. Buffer reloaded.", "WarningMsg"}}, false, {})
    end
})

-- Highlight on yank
local yankGrp = vim.api.nvim_create_augroup("YankHighlight", {
    clear = true
})
vim.api.nvim_create_autocmd("TextYankPost", {
    group = yankGrp,
    pattern = "*",
    callback = function()
        vim.highlight.on_yank({
            higroup = "IncSearch",
            timeout = 120
        })
    end
})

-- Restore cursor position
vim.api.nvim_create_autocmd("BufReadPost", {
    callback = function()
        local mark = vim.api.nvim_buf_get_mark(0, '"')
        local lcount = vim.api.nvim_buf_line_count(0)
        if mark[1] > 0 and mark[1] <= lcount then
            pcall(vim.api.nvim_win_set_cursor, 0, mark)
        end
    end
})

-- GitSigns highlight tweaks (safe even if plugin not loaded yet)
vim.api.nvim_set_hl(0, "GitSignsAdd", {
    fg = "#00aa00",
    bg = "NONE"
})
vim.api.nvim_set_hl(0, "GitSignsChange", {
    fg = "#aaaa00",
    bg = "NONE"
})
vim.api.nvim_set_hl(0, "GitSignsDelete", {
    fg = "#ff3333",
    bg = "NONE"
})

-- Tree-sitter based folding for languages that benefit from structural folds
local tsFoldGrp = vim.api.nvim_create_augroup("TreesitterFolds", {
    clear = true
})
vim.api.nvim_create_autocmd("FileType", {
    group = tsFoldGrp,
    pattern = {"bash", "css", "dockerfile", "groovy", "hcl", "html", "ini", "json", "lua", "markdown", "python",
               "query", "regex", "sql", "toml", "vim", "vimdoc", "xml", "yaml"},
    callback = function()
        if vim.fn.exists("*nvim_treesitter#foldexpr") > 0 then
            vim.opt_local.foldmethod = "expr"
            vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
            vim.opt_local.foldlevel = 99
            vim.opt_local.foldlevelstart = 99
            vim.opt_local.foldenable = true
        end
    end
})

return {}
