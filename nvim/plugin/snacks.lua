vim.pack.add({
	"https://github.com/folke/snacks.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
})

require("snacks").setup({
	picker = {
		enabled = true,
		layout = {
			layout = {
				backdrop = 80,
			},
		},
		sources = {
			explorer = {
				matcher = {
					fuzzy = true,
				},
				auto_close = true,
				layout = {
					preset = "vertical",
					layout = { max_width = 50 }
				},
			}
		}
	},
	indent = {
			only_current = true,
		indent = {
			char = "▎",
		},
		animate = {
			enabled = false,
		},
		scope = {
			enabled = true,
			char = "▎",
			hl = "Comment",
		},
	},
	bufdelete = {
		enabled = true
	},
	notifier = {
		enabled = true
	},
	bigfile = {
		enabled = true
	},
	quickfile = {
		enabled = true
	},
	input = {
		enabled = true
	},
	explorer = {
		enabled = true,
		replace_netrw = true,
		trash = true, -- use the system trash when deleting files
	},
})

vim.api.nvim_set_hl(0, "SnacksIndent", { link = "LineNr" })

local keys = {
	{
		"<leader>bd",
		function() Snacks.bufdelete() end,
		desc = "delete buffer"
	},
	-- LSP/DIAGNOSTICS
	{
		";R",
		function() Snacks.picker.lsp_references() end,
		desc = "go to references"
	},
	{
		"<leader>sl",
		function() Snacks.picker.lsp_symbols() end,
		desc = "LSP symbols (current file)"
	},
	{
		"<leader>sL",
		function() Snacks.picker.lsp_workspace_symbols() end,
		desc = "LSP symbols (workspace)"
	},
	{
		"<leader>sd",
		function() Snacks.picker.diagnostics() end,
		desc = "diagnostics"
	},
	-- SEARCHING
	{
		"<leader>ss",
		function() Snacks.picker.grep() end,
		desc = "current folder"
	},
	{
		"<leader>sg",
		function() Snacks.picker.git_log() end,
		desc = "git commits"
	},
	-- FILE EXPLORER
	{
		"<leader>f",
		function() Snacks.explorer() end,
		desc = "file explorer"
	},
}

for _, key in ipairs(keys) do
	vim.keymap.set("n", key[1], key[2], { desc = key.desc })
end

-- make :bd use Snacks.bufdelete, which keeps the window layout intact.
-- supports :bd!, :bd 3 and :bd name
vim.api.nvim_create_user_command("Bd", function(cmd)
	local buf = tonumber(cmd.args) or (cmd.args ~= "" and vim.fn.bufnr(cmd.args)) or 0
	Snacks.bufdelete({ buf = buf, force = cmd.bang })
end, { bang = true, nargs = "?", complete = "buffer", desc = "delete buffer" })

vim.keymap.set("ca", "bd", function()
	return vim.fn.getcmdtype() == ":" and vim.fn.getcmdline() == "bd" and "Bd" or "bd"
end, { expr = true })
