-- Core: which-key registrations
local ok, wk = pcall(require, "which-key")
if not ok then
	return {}
end

wk.add({
	{ "<leader>w", desc = "Write file" },
	{ "<leader>q", desc = "Quit" },
	{ "<leader>d", desc = "Diagnostics" },
	{ "<leader>e", desc = "File explorer" },
	{ "<leader>h", desc = "Clear search highlight" },
	{ "<leader>t", group = "toggle" },
	{ "<leader>tn", desc = "Relative number" },
	{ "<leader>l", group = "diagnostics" },
	{ "<leader>ld", desc = "Line diagnostics" },
	{ "<leader>lq", desc = "Diagnostics to loclist" },
	-- Git (gitsigns) group & mappings
	{ "<leader>h", group = "git (hunks)" },
	{ "<leader>hs", desc = "Stage hunk" },
	{ "<leader>hr", desc = "Reset hunk" },
	{ "<leader>hS", desc = "Stage buffer" },
	{ "<leader>hR", desc = "Reset buffer" },
	{ "<leader>hp", desc = "Preview hunk" },
	{ "<leader>hi", desc = "Preview hunk inline" },
	{ "<leader>hb", desc = "Blame line (full)" },
	{ "<leader>hd", desc = "Diff this" },
	{ "<leader>hD", desc = "Diff vs HEAD~" },
	{ "<leader>hQ", desc = "Quickfix all hunks" },
	{ "<leader>hq", desc = "Quickfix hunks (current)" },
	{ "<leader>hu", desc = "Undo stage hunk" },
	{ "<leader>tb", desc = "Toggle line blame" },
	{ "<leader>tw", desc = "Toggle word diff" },
	-- Comment plugin operator + line toggle (mini.comment)
	{ "gc", desc = "Comment operator", mode = { "n", "x" } },
	{ "gcc", desc = "Toggle line comment", mode = "n" },
})

return {}
