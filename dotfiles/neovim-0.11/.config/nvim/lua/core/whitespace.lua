-- Core: reveal whitespace only when the cursor is directly on top of it.
local M = {}

local ns = vim.api.nvim_create_namespace("ContextualWhitespace")

vim.api.nvim_set_hl(0, "WhitespaceReveal", { link = "DiagnosticError" })

local function clear(bufnr)
	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

local function add_marker(bufnr, row, col, text)
	vim.api.nvim_buf_set_extmark(bufnr, ns, row, col, {
		virt_text = { { text, "WhitespaceReveal" } },
		virt_text_pos = "overlay",
		hl_mode = "combine",
		priority = 200,
	})
end

local function reveal_in_range(bufnr, line_nr, start_col, end_col)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line or line == "" then
		return
	end

	local last_col = math.min(end_col, #line)
	for col = math.max(start_col, 1), last_col do
		local char = line:sub(col, col)
		if char == " " then
			add_marker(bufnr, line_nr - 1, col - 1, "·")
		elseif char == "\t" then
			add_marker(bufnr, line_nr - 1, col - 1, "»")
		end
	end
end

local function reveal_at_cursor(bufnr)
	local pos = vim.api.nvim_win_get_cursor(0)
	local line_nr = pos[1]
	local col = pos[2]
	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line or line == "" then
		return
	end

	local char = line:sub(col + 1, col + 1)
	if char == " " then
		add_marker(bufnr, line_nr - 1, col, "·")
	elseif char == "\t" then
		add_marker(bufnr, line_nr - 1, col, "»")
	end
end

local function reveal_visual_selection(bufnr)
	local mode = vim.fn.mode(1)
	if not mode:match("[vV\22]") then
		return false
	end

	local start_pos = vim.fn.getpos("v")
	local end_pos = vim.fn.getpos(".")
	local start_line = start_pos[2]
	local end_line = end_pos[2]
	local start_col = start_pos[3]
	local end_col = end_pos[3]

	if start_line > end_line or (start_line == end_line and start_col > end_col) then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	for line_nr = start_line, end_line do
		local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1] or ""
		local from_col = 1
		local to_col = #line

		if mode:match("[v\22]") then
			if line_nr == start_line then
				from_col = start_col
			end
			if line_nr == end_line then
				to_col = end_col
			end
		end

		if mode:match("\22") then
			from_col = math.min(start_col, end_col)
			to_col = math.max(start_col, end_col)
		end

		reveal_in_range(bufnr, line_nr, from_col, to_col)
	end

	return true
end

function M.refresh()
	local bufnr = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	clear(bufnr)
	if not reveal_visual_selection(bufnr) then
		reveal_at_cursor(bufnr)
	end
end

local group = vim.api.nvim_create_augroup("ContextualWhitespace", { clear = true })

vim.api.nvim_create_autocmd({
	"BufEnter",
	"CursorMoved",
	"CursorMovedI",
	"ModeChanged",
	"TextChanged",
	"TextChangedI",
	"WinEnter",
}, {
	group = group,
	callback = function()
		vim.schedule(M.refresh)
	end,
})

return M
