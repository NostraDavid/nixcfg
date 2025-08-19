-- Python-specific configuration
-- This file is loaded for Python files only

-- Set Python-specific options
vim.bo.tabstop = 4
vim.bo.shiftwidth = 4
vim.bo.expandtab = true
vim.bo.softtabstop = 4

-- Python-specific keymaps
local function map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.buffer = true
  vim.keymap.set(mode, lhs, rhs, opts)
end

-- Quick run Python file
map('n', '<leader>rp', '<cmd>!python %<CR>', { desc = '[R]un [P]ython file' })

-- Quick run Python in terminal
map('n', '<leader>rt', '<cmd>TermExec cmd="python %"<CR>', { desc = '[R]un in [T]erminal' })

-- Python REPL
map('n', '<leader>ri', '<cmd>TermExec cmd="python -i %"<CR>', { desc = '[R]un [I]nteractive' })

-- Virtual environment helpers
vim.api.nvim_create_user_command('PythonVenv', function()
  -- Try to detect virtual environment
  local venv_path = vim.fn.finddir('.venv', vim.fn.getcwd() .. ';')
  if venv_path ~= '' then
    local python_path = venv_path .. '/bin/python'
    if vim.fn.executable(python_path) then
      print('Using Python from: ' .. python_path)
    end
  else
    print('No virtual environment found')
  end
end, { desc = 'Check Python virtual environment' })

-- Set up Python path for LSP if in virtual environment
local function setup_python_path()
  local venv_path = vim.fn.finddir('.venv', vim.fn.getcwd() .. ';')
  if venv_path ~= '' then
    local python_path = venv_path .. '/bin/python'
    if vim.fn.executable(python_path) then
      vim.g.python3_host_prog = python_path
    end
  end
end

setup_python_path()
