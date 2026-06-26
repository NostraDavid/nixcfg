-- Core: VS Code compatibility helpers.
local M = {}

local terminal = {
	bufnr = nil,
	winid = nil,
}

local function valid_buf(bufnr)
	return bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr)
end

local function valid_win(winid)
	return winid ~= nil and vim.api.nvim_win_is_valid(winid)
end

function M.toggle_terminal()
	if valid_win(terminal.winid) then
		vim.api.nvim_win_close(terminal.winid, true)
		terminal.winid = nil
		return
	end

	local height = math.max(10, math.floor(vim.o.lines * 0.25))
	vim.cmd("botright split")
	vim.cmd(("resize %d"):format(height))

	if valid_buf(terminal.bufnr) then
		vim.api.nvim_win_set_buf(0, terminal.bufnr)
	else
		vim.cmd("terminal")
		terminal.bufnr = vim.api.nvim_get_current_buf()
		vim.bo[terminal.bufnr].bufhidden = "hide"
	end

	terminal.winid = vim.api.nvim_get_current_win()
	vim.cmd("startinsert")
end

function M.move_line_down()
	vim.cmd("move .+1")
	vim.cmd("normal! ==")
end

function M.move_line_up()
	vim.cmd("move .-2")
	vim.cmd("normal! ==")
end

function M.move_selection_down()
	vim.cmd("'<,'>move '>+1")
	vim.cmd("normal! gv=gv")
end

function M.move_selection_up()
	vim.cmd("'<,'>move '<-2")
	vim.cmd("normal! gv=gv")
end

return M
