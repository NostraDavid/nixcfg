-- Core: show whitespace markers only on the current line or active visual selection.
local M = {}

local ns = vim.api.nvim_create_namespace("ContextualWhitespace")

vim.api.nvim_set_hl(0, "WhitespaceReveal", { link = "NonText" })

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

local function reveal_line(bufnr, line_nr)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line or line == "" then
		return
	end

	local from = 1
	while true do
		local start_col, end_col = line:find("\t", from, true)
		if not start_col then
			break
		end
		add_marker(bufnr, line_nr - 1, start_col - 1, "»")
		from = end_col + 1
	end

	local trail_start = line:find("[ \t]+$")
	if not trail_start then
		return
	end

	for col = trail_start, #line do
		local char = line:sub(col, col)
		if char == " " then
			add_marker(bufnr, line_nr - 1, col - 1, "·")
		elseif char == "\t" then
			add_marker(bufnr, line_nr - 1, col - 1, "»")
		end
	end
end

local function target_range()
	local mode = vim.fn.mode(1)
	if mode:match("[vV\22]") then
		local start_pos = vim.fn.getpos("v")
		local end_pos = vim.fn.getpos(".")
		return math.min(start_pos[2], end_pos[2]), math.max(start_pos[2], end_pos[2])
	end

	local line = vim.api.nvim_win_get_cursor(0)[1]
	return line, line
end

function M.refresh()
	local bufnr = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	clear(bufnr)

	local first_line, last_line = target_range()
	for line_nr = first_line, last_line do
		reveal_line(bufnr, line_nr)
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
